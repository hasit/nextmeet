# NextMeet

NextMeet is a tiny macOS menu bar app for today's meeting links.

It reads Calendar events for the current day, finds join links, and opens each
meeting in the default app for that link.

## Features

- Shows today's meeting links in the menu bar
- Refreshes when the menu opens
- Sends opt-in macOS notifications before upcoming meetings
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
6. Turn on Meeting Alerts if you want a notification before each meeting.

Meeting Alerts work best with Launch at Startup enabled so NextMeet is already
running before your first meeting of the day.

Current release builds are not notarized unless Apple Developer ID secrets are
configured in GitHub Actions. If macOS shows `"NextMeet" Not Opened`, choose
Done, then open System Settings > Privacy & Security and click Open Anyway for
NextMeet.

Building from source avoids this downloaded-app warning.

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

To notarize release ZIPs from GitHub Actions, configure these repository
secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
