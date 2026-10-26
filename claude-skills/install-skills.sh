#!/usr/bin/env bash
# Installs the design skills for Claude Code into ~/.claude so they work in every project.
#
#   ./claude-skills/install-skills.sh                    # install or update everything
#   ./claude-skills/install-skills.sh --no-open-design   # skip the Open Design skill pack
#   ./claude-skills/install-skills.sh --force            # reinstall even if up to date
#   ./claude-skills/install-skills.sh --uninstall        # remove everything this script installed
#
# Third-party sources are pinned to exact commits/versions. To update, change the pins below.
set -euo pipefail

ANTHROPIC_SKILLS_SHA="dbd4588f9e1033efb41dad4bef2f7947c8993d44"   # anthropics/skills
IMPECCABLE_SHA="3671d50f0ac9a662ce0615e85a256110c9cd720b"         # pbakaus/impeccable
OPEN_DESIGN_SHA="9724c44142ea0afaee3d207f37901b31c66a44ad"        # nexu-io/open-design
SKILLUI_VERSION="1.3.4"                                            # npm: skillui
PLAYWRIGHT_CLI_VERSION="0.1.22"                                    # npm: @playwright/cli

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
MANIFEST="$CLAUDE_DIR/.design-skills-manifest"
STAMP="$CLAUDE_DIR/.design-skills-stamp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_OPEN_DESIGN=1
FORCE=0
UNINSTALL=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --no-open-design) WITH_OPEN_DESIGN=0 ;;
        --force) FORCE=1 ;;
        --uninstall) UNINSTALL=1 ;;
        --quiet) QUIET=1 ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

log() { [ "$QUIET" = 1 ] || echo "$@"; }
warn() { echo "warning: $*" >&2; }

# Remove everything a previous run installed (tracked in the manifest), never anything else.
remove_managed() {
    [ -f "$MANIFEST" ] || return 0
    while IFS= read -r path; do
        case "$path" in
            "$SKILLS_DIR"/?*|"$AGENTS_DIR"/?*) rm -rf "$path" ;;
        esac
    done < "$MANIFEST"
    rm -f "$MANIFEST" "$STAMP"
}

if [ "$UNINSTALL" = 1 ]; then
    remove_managed
    log "Removed the design skills. (the CLIs stay installed; remove them with: npm uninstall -g skillui @playwright/cli)"
    exit 0
fi

# Claude Code cloud containers have Playwright's Chromium but no Google Chrome, which playwright-cli
# defaults to. When run from a SessionStart hook, point it at that Chromium for the whole session.
CLOUD_CHROMIUM="/opt/pw-browsers/chromium"
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -x "$CLOUD_CHROMIUM" ] && [ ! -x /opt/google/chrome/chrome ]; then
    {
        echo "export PLAYWRIGHT_MCP_BROWSER=chromium"
        echo "export PLAYWRIGHT_MCP_EXECUTABLE_PATH=$(readlink -f "$CLOUD_CHROMIUM")"
    } >> "$CLAUDE_ENV_FILE"
fi

WANT="$ANTHROPIC_SKILLS_SHA $IMPECCABLE_SHA $OPEN_DESIGN_SHA $SKILLUI_VERSION $PLAYWRIGHT_CLI_VERSION od=$WITH_OPEN_DESIGN $(cksum < "$SCRIPT_DIR/skillui/SKILL.md")"
if [ "$FORCE" = 0 ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT" ]; then
    log "Design skills are already up to date in $SKILLS_DIR"
    exit 0
fi

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# fetch <owner/repo> <sha> <dest> <sparse paths...>: shallow, partial checkout of only the paths we need.
fetch() {
    local repo="$1" sha="$2" dest="$3"; shift 3
    git init -q "$dest"
    git -C "$dest" remote add origin "https://github.com/$repo.git"
    git -C "$dest" sparse-checkout set --no-cone "$@"
    git -C "$dest" fetch -q --depth 1 --filter=blob:none origin "$sha"
    git -C "$dest" checkout -q FETCH_HEAD
}

log "Downloading pinned sources..."
fetch anthropics/skills "$ANTHROPIC_SKILLS_SHA" "$TMP/anthropic" "/skills/frontend-design/"
fetch pbakaus/impeccable "$IMPECCABLE_SHA" "$TMP/impeccable" "/plugin/skills/" "/plugin/agents/"
if [ "$WITH_OPEN_DESIGN" = 1 ]; then
    fetch nexu-io/open-design "$OPEN_DESIGN_SHA" "$TMP/open-design" "/skills/"
fi

remove_managed
mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"
: > "$MANIFEST.new"
installed=0
skipped=()
duplicates=0

# install_item <src> <dest-dir>: copies unless something not installed by us already uses the name.
install_item() {
    local src="$1" dest="$2/$(basename "$1")"
    if [ -e "$dest" ]; then
        if grep -qxF "$dest" "$MANIFEST.new"; then
            duplicates=$((duplicates + 1))
        else
            skipped+=("$(basename "$1")")
        fi
        return 0
    fi
    cp -R "$src" "$dest"
    echo "$dest" >> "$MANIFEST.new"
    installed=$((installed + 1))
}

# Order matters: on a name clash the first one wins (the official frontend-design beats Open Design's copy).
install_item "$TMP/anthropic/skills/frontend-design" "$SKILLS_DIR"
install_item "$TMP/impeccable/plugin/skills/impeccable" "$SKILLS_DIR"
for agent in "$TMP"/impeccable/plugin/agents/*.md; do
    install_item "$agent" "$AGENTS_DIR"
done
install_item "$SCRIPT_DIR/skillui" "$SKILLS_DIR"
if [ "$WITH_OPEN_DESIGN" = 1 ]; then
    for dir in "$TMP"/open-design/skills/*/; do
        [ -f "$dir/SKILL.md" ] && install_item "${dir%/}" "$SKILLS_DIR"
    done
fi
chmod +x "$SKILLS_DIR/impeccable/scripts/impeccable" 2>/dev/null || true

# npm_global <package> <version> <command>: installs a CLI globally unless that version is already present.
npm_global() {
    if [ "$("$3" --version 2>/dev/null || true)" = "$2" ]; then
        return 0
    fi
    if npm install -g --silent "$1@$2" >/dev/null 2>&1; then
        log "Installed the $3 CLI $2."
    else
        warn "couldn't install $1 globally (try: sudo npm install -g $1@$2)."
        return 1
    fi
}

if command -v npm >/dev/null; then
    # The skillui skill falls back to npx, so a failed global install is not fatal.
    npm_global skillui "$SKILLUI_VERSION" skillui || true

    # Playwright CLI ships its own skill; let it write the skill so it matches the CLI version.
    if npm_global @playwright/cli "$PLAYWRIGHT_CLI_VERSION" playwright-cli; then
        pw_skill="$SKILLS_DIR/playwright-cli"
        pw_existed=0
        [ -e "$pw_skill" ] && pw_existed=1
        if (cd "$HOME" && playwright-cli install --skills -g >/dev/null 2>&1) && [ -f "$pw_skill/SKILL.md" ]; then
            [ "$pw_existed" = 0 ] && { echo "$pw_skill" >> "$MANIFEST.new"; installed=$((installed + 1)); }
        else
            warn "couldn't install the playwright-cli skill (run: playwright-cli install --skills -g)."
        fi
    fi
else
    warn "npm not found. Install Node.js 18+ for the skillui and playwright-cli CLIs."
fi

mv "$MANIFEST.new" "$MANIFEST"
echo "$WANT" > "$STAMP"

log "Installed $installed skills/agents into $CLAUDE_DIR ($duplicates duplicate names skipped; the first source wins)."
if [ "${#skipped[@]}" -gt 0 ]; then
    log "Skipped ${#skipped[@]} that already exist and weren't installed by this script: ${skipped[*]}"
fi
log "Restart Claude Code (or start a new session) to load them."
