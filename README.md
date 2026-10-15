# Zoom Caption Saver

A local macOS menu bar app that watches the caption table in Zoom 7.1.9 and saves timestamped text. It reads macOS Accessibility data. It does not record audio, send data to a service, attach to Zoom, or change Zoom's transcription settings.

## Build and run

Requires Xcode command-line Swift tools and macOS 13 or later.

```sh
zsh build-app.sh
open 'build/Zoom Caption Saver.app'
```

Open **System Settings → Privacy & Security → Accessibility**, add `build/Zoom Caption Saver.app`, and enable it. macOS requires the user to grant this permission. The app displays **Accessibility required** until it has access.

Leave the app running and enable captions in Zoom. The **CC** menu shows waiting or recording status, opens the transcript folder/latest file, and provides **Quit**. It does not launch Zoom.

Automatic launch at login is configured for this user through `~/Library/LaunchAgents/local.zoom-caption-saver.plist`. The source configuration is `config/local.zoom-caption-saver.plist`. It opens the existing app in the background once per login. Choosing **Quit** keeps the app closed until you open it again or log in next time.

To disable automatic launch:

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.zoom-caption-saver.plist"
rm "$HOME/Library/LaunchAgents/local.zoom-caption-saver.plist"
```

The app expects to remain in this workspace's `build` directory. Moving it changes the relative data-folder location.

## Files and behavior

- One `.txt` file is created in `transcripts` when the first nonempty caption is observed in a meeting.
- Text and speaker names are preserved in the combined form exposed by Zoom's accessibility labels.
- Timestamps are UTC and mark when a speaker row was first observed locally. They are not exact speech or sentence timestamps. A row can contain several sentences.
- The app polls every 750 ms. Changes to an existing row replace that row's text in the saved transcript. Repeated unchanged polls do not add duplicates.
- File updates are atomic. Files are owner-readable/writable; newly created transcript directories are owner-only.
- Captions disappearing or being hidden do not erase saved history. A new meeting window starts a separate file.
- Read errors retain the current session and retry. Save errors remain visible in the menu and are retried. Quit refuses to discard pending captions if saving fails.

## Validation and limits

The core tests cover revisions, duplicate polls, legitimate repeated words, rows disappearing/reappearing, transcript contents, and meeting boundaries:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
  xcrun swift test --disable-sandbox --cache-path .build/package-cache --scratch-path .build/swiftpm
```

Live testing on 2026-10-15 confirmed an `AXTable` named `Closed caption subtitles` in the meeting window, containing row/cell/static-text descendants with the speaker name and caption. After the user enabled Accessibility, the standalone app saved the speaker name and test speech into one file. A second spoken sentence updated that same file without duplicating the first text. The file remained intact after the user ended the meeting, with owner-only read/write permissions (`0600`). All 11 core tests passed. Separate-file behavior across meetings is unit-tested; a second live meeting and long-session row recycling have not been tested.

This version targets the observed English caption-table label and meeting-window identifier in the installed Zoom build. Zoom updates or a different UI language may require adapting detection. The recorder captures only captions Zoom exposes while it is running; it cannot recover earlier speech or guarantee capture of changes that occur entirely between polls. Accessibility does not expose Zoom's underlying transcript message IDs, so very long meetings with recycled row identities need additional live validation.

**Save Caption Diagnostic** writes only the current caption subtree to `evidence/caption-table-*.json`. It contains the displayed test/meeting text, so use it deliberately. Ordinary recording does not produce diagnostic snapshots.

The REA investigation and its method-level evidence remain in `../rea/zoom-caption-findings.txt` and `../rea/evidence/zoom-captions-rea.json`.
