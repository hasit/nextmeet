# NextMeet

NextMeet is a macOS menu bar app that reads today's calendar events, finds
meeting links, and keeps today's joinable meetings one click away.

The menu contains:

- Today's remaining meetings with links
- Refresh
- Launch at Startup
- Quit

Build a launchable app:

```bash
./script/build_app.sh
```

The app bundle is created at `dist/NextMeet.app`. Double-click it to launch.
Because NextMeet is a menu bar utility, launching it shows the calendar icon in
the menu bar instead of opening a Dock app window.

Regenerate the app icon:

```bash
./script/generate_app_icon.sh
```

Build and run for development:

```bash
./script/build_and_run.sh
```
