# YPK Stage Control Pro

A browser-based stage timer and confidence-monitor system for live events. An operator runs the agenda from a laptop. Stage TVs, speaker monitors and streaming overlays in other places pick up the same room code and stay in sync in real time through Firebase.

The whole app is a single file, `index.html`. There is no build step and nothing to install.

## Features

- **Live rundown.** Build the agenda with start times, durations, topics and speakers. Drag rows to reorder them, and later start times recalculate automatically.
- **Session timers.** Start, pause, resume and stop the timer, or add/subtract a minute. A quick timer runs independently of the agenda, and a master clock shows the time of day.
- **Time's-up alerts.** The stage display flashes when the active session runs over.
- **Banner messages.** Send a short message (for example "Wrap it up!") to every display.
- **Speaker notes.** Type notes separated by `---`, or import them from a `.pptx`. The current slide's notes and a preview of the next slide show on the prompter.
- **Screen sharing.** The operator can share a screen or window to the stage displays over WebRTC (PeerJS), crop it, and arrange it with the timer and notes.
- **Layout manager.** Choose Timer Only, Notes Only, Screen Only, Split, or Screen Top / Timer Bottom, then adjust split sizes and swap the order.
- **Several outputs from one room:**
  | Output | URL params | Purpose |
  |---|---|---|
  | Controller | `?room=CODE&role=operator` | Full control (also used for co-operators) |
  | Stage Display | `?room=CODE&role=prompter` | Audience-facing screen; follows the Layout Manager |
  | Speaker Monitor | `?room=CODE&role=prompter&view=speaker` | Always shows the timer and notes, even when the stage is set to Screen Only |
  | OBS / Stream Overlay | `?room=CODE&role=prompter&view=obs` | Transparent timer with no UI, for a browser source in OBS or vMix |

  The **🔗 Output Links** dialog in the operator view builds these URLs for you, with copy buttons and QR codes.
- **Templates.** Save agendas as named templates in the room's shared cloud storage.
- **Archives.** Ending an event archives its agenda along with the actual and planned timings. You can reload past agendas or export an Excel audit report.
- **Presence.** The operator header shows how many displays are connected.

## Quick start

1. Serve the folder over HTTP. Screen sharing, the clipboard and fullscreen all need a secure context (`https://` or `localhost`):
   ```bash
   python3 -m http.server 8080
   # then open http://localhost:8080
   ```
   Any static host also works, for example GitHub Pages, Netlify or Firebase Hosting.
2. **Operator:** enter a room code under *Operator Dashboard*, or click **⚡ Random** to generate one, then start.
3. **Displays:** on each TV or monitor, open the app and enter the same code under *Join Stage TV / Prompter*. You can also open one of the output links directly.
4. Build or import the rundown, then click **Start** on a row to run it.

## Importing data

Use **📥 Import** in the rundown panel, or drop a file onto it.

**Spreadsheet (`.xlsx` / `.csv`).** The first row is treated as a header. Each later row needs these columns:

| A: Start time | B: Duration | C: Topic | D: Speaker |
|---|---|---|---|
| `09:00` | `30` (minutes) or `1:30` (h:mm) | Opening Keynote | Jane Doe |

If a duration is missing or invalid, it defaults to 15 minutes.

**PowerPoint (`.pptx`).** The app extracts the speaker notes from each slide into the Live Notes panel, one slide per `---` block.

## Keyboard shortcuts

These apply when no text field has focus.

| Key | Action |
|---|---|
| `F` | Toggle fullscreen |
| `→` / `PageDown` | Next slide's notes |
| `←` / `PageUp` | Previous slide's notes |
| `Esc` | Close the open dialog |

A presentation clicker that sends PageUp/PageDown also advances the notes.

## Configuration

Firebase settings are in the `firebaseConfig` block near the top of `index.html`. To use your own backend:

1. Create a Firebase project and turn on the **Realtime Database**.
2. Replace the values in `firebaseConfig` with your project's values.
3. Set database rules that suit how you deploy. The app reads and writes `rooms/<code>` (live state and presence) and `archives/<key>` (ended events).

Firebase web API keys are not secret, but anyone with the config can reach the database unless your rules restrict them. Lock the rules down before a public deployment.

## Data and privacy

- Live room state goes to Firebase. Ending an event wipes the room and writes an archive entry. You must type the room code to confirm.
- Screen-share video goes peer-to-peer over WebRTC and is not stored.
- **🧹 Clear Local History Cache** clears what this browser has saved locally (`localStorage`).

## Dependencies

All dependencies load from CDNs at runtime: Tailwind CSS, Firebase v8 (app and database), PeerJS, SheetJS (`xlsx`), JSZip and Tesseract.js. Every device running the app needs internet access.

## Project structure

```
index.html   # The entire app: markup, styles, Firebase config and logic
README.md
```
