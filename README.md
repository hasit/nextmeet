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

## Download

Download the latest release:

https://github.com/hasit/nextmeet/releases/latest/download/NextMeet.zip

To run NextMeet:

1. Unzip `NextMeet.zip`.
2. Move `NextMeet.app` to Applications.
3. Open NextMeet.
4. Grant Calendar access when macOS asks.
5. Use the calendar icon in the menu bar.

If macOS blocks the app the first time, Control-click `NextMeet.app` and choose
Open.

## Build From Source

Requires Xcode command line tools.

```bash
./script/build_app.sh
```

The app bundle is created at `dist/NextMeet.app`.

For local development:

```bash
./script/build_and_run.sh
```

To create a release ZIP locally:

```bash
./script/package_release.sh
```
