# Design skills for Claude Code

`install-skills.sh` installs these design tools into `~/.claude/` so Claude Code can use them in every project:

| Tool | What you get | Source (pinned) |
|---|---|---|
| **Frontend Design** (Anthropic) | The `frontend-design` skill: stronger aesthetic direction and typography, and fewer templated-looking defaults | [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/frontend-design) |
| **Impeccable** | The `/impeccable` skill (shape, audit, critique, polish, animate, bolder, quieter…), its anti-pattern detector, and 4 helper subagents | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) |
| **SkillUI** | The `skillui` CLI, plus a `skillui` skill that tells Claude when and how to extract a design system from a URL, repo or folder | [npm: skillui](https://www.npmjs.com/package/skillui) · [amaancoderx/npxskillui](https://github.com/amaancoderx/npxskillui) |
| **Open Design** skill pack | Open Design's ~170 skills: design taste, motion and GSAP, decks, Figma, frame and video templates, and more | [nexu-io/open-design](https://github.com/nexu-io/open-design/tree/main/skills) |

## On your computer (once)

```bash
git clone https://github.com/yongky-sketch/ypk.git
cd ypk
git checkout claude/intelligent-carson-6kstou   # until this is merged into main
./claude-skills/install-skills.sh
```

Restart Claude Code afterwards. Run the same command again later to update; it does nothing if you're already up to date.

Requirements: `git` and `bash` (macOS, Linux, or WSL on Windows). The SkillUI CLI also needs Node.js 18+. If the global npm install fails, the skill falls back to `npx`.

Options:
- `--no-open-design`: install only the first three tools. Use this if the long skill list is too much noise.
- `--force`: reinstall even if already up to date.
- `--uninstall`: remove everything this script installed. It never touches skills you added yourself.

## In Claude Code cloud sessions

`.claude/settings.json` runs the installer at the start of every cloud session that uses this repo, so the skills are always available there. Local sessions are skipped, since you've already installed the skills globally.

## Notes

- If a skill or agent with the same name already exists in `~/.claude`, and this script didn't install it, the script skips it rather than overwriting it.
- Impeccable's full setup (`npx impeccable install`) can also add a per-project edit hook that runs its detector automatically. This installer only adds the skill. Run `npx impeccable install` inside a project if you want that hook too.
- Open Design is also a desktop app. Some of its skills (for example `brand-extract` and `library-curator`) expect the app or its MCP server (`od mcp install claude`); they're harmless without it.
- To update a tool, change its pinned commit or version at the top of `install-skills.sh`.
