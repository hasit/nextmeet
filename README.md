# NextMeet

NextMeet is a tiny macOS menu bar app for today's meeting links.

It reads Calendar events for the current day, finds join links, and opens each
meeting in the default app for that link.

## Features

- Shows today's meeting links in the menu bar
- Refreshes when the menu opens
- Opens links for Zoom, Google Meet, Microsoft Teams, Webex, and generic web meetings
- Supports launch at login
- Keeps calendar data on your Mac

## Requirements

- macOS 14 or newer
- Xcode command line tools

## Build

```bash
./script/build_app.sh
```

The app bundle is created at `dist/NextMeet.app`.

For local development:

```bash
./script/build_and_run.sh
```
