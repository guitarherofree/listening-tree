# Updating the installed app

## How the in-app updater works

1. **Checking.** At most once a day (at startup, or later if the app stays
   open; never during playback or recording), and whenever you choose
   **File › Check for updates…**, the app asks GitHub for the newest release of
   `guitarherofree/listening-tree` and compares its version with its own.
   Turn the daily check off in **Preferences › General › Automatic update check**.
2. **Choosing.** If there is a newer version, a window shows its release
   notes, plus the notes of any versions in between that you skipped. You choose
   **Install update**, **Remind me later**, or **Skip this version**.
3. **Downloading.** The disk image for your kind of Mac is downloaded with a
   progress bar and checked against the SHA-256 checksum GitHub recorded when
   it was uploaded. A damaged download is discarded.
4. **Installing.** The app asks to close (and to save any unsaved projects),
   then quits. A helper script (`packaging/macos/install-update.sh`, inside
   the app) then:
   - waits until the app has fully quit,
   - checks that the new app is Listening Tree and that its signature is intact,
   - backs up your settings to
     `~/Library/Application Support/ListeningTree/ListeningTree/UpdateBackups/`
     (the newest five backups are kept),
   - replaces the app and moves the old version to the Trash,
   - opens the new version, which brings itself to the front.

   If anything fails, the old version stays where it was, a message explains
   what happened, and the downloaded disk image is kept so you can install it
   by hand. Every step is logged in `~/Library/Logs/Listening Tree/updates.log`.

### What an update never touches

- **Your projects** (`.aup4` files and their audio), wherever you saved them.
- **Your settings**:
  `~/Library/Preferences/com.guitarherofree.ListeningTree.plist` and
  `~/Library/Application Support/ListeningTree/ListeningTree/`
  (preferences, workspaces and the app's other data). Only the app bundle
  in `/Applications` is replaced.

Development builds keep separate settings (`…ListeningTreeDev…`), so trying a
build from `scripts/run.sh` never changes the installed app's settings either.

## GitHub token (while the repository is private)

GitHub only shows a private repository's releases to signed-in users, so the
updater needs a read-only token. Without one, or with one that can't read the
repository, **File › Check for updates…** says so ("Couldn't check for updates … update token …").

1. Go to <https://github.com/settings/personal-access-tokens/new>
   (a "fine-grained" token).
   - **Token name:** Listening Tree updates
   - **Expiration:** your choice (when it expires, make a new one and repeat step 2)
   - **Repository access:** Only select repositories › `listening-tree`
     (the default, "Public repositories", can't see this private repository)
   - **Permissions › Repository permissions › Contents:** Read-only
2. On your Mac, store it in your login Keychain:

   ```sh
   scripts/set-update-token.sh          # paste the token when asked; it checks it with GitHub
   ```

The app reads it from the Keychain each time it checks. It is sent only to
`api.github.com`, never to the server the download comes from.
`scripts/set-update-token.sh --check` tests it and `--remove` deletes it (for
example if you make the repository public, which makes the token unnecessary).

## Installing by hand

```sh
scripts/install.sh --latest                  # download the newest release and install it
scripts/install.sh --version 0.1.0           # a specific release
scripts/install.sh dist/ListeningTree-0.2.0-arm64.dmg   # a disk image you built
```

This uses the same helper as the in-app updater (settings backup, old version
to the Trash). Or install like any Mac app: open the disk image and drag
**Listening Tree** onto **Applications**.

### The first time you open a downloaded copy

The app is not notarized by Apple (that needs a paid developer account), so
when a copy downloaded with a web browser is opened for the first time, macOS
says it can't verify it. Open **System Settings › Privacy & Security**, scroll
down, click **Open Anyway** next to the message about Listening Tree, and
confirm. You only do this once. Copies installed with `scripts/install.sh` and
updates installed by the app don't ask.

### Microphone permission after an update

macOS ties the microphone permission to the app's code signature. With the
default ad-hoc signature, every build has a different signature, so macOS may
ask for microphone access again after an update. Allow it and recording works
as before. To avoid the question, sign builds with a certificate that stays
the same: create a free "Apple Development" certificate in Xcode (Settings ›
Accounts › Manage Certificates › +), then before building or releasing run
`export LT_CODESIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)"`
(the exact name is shown by `security find-identity -v -p codesigning`).

## Going back to an earlier version

- The version you had before the last update is in the **Trash**, named like
  "Listening Tree 0.1.0.app". Drag it back to Applications (replace the newer one).
- Or install any published version: `scripts/install.sh --version 0.1.0`.
- Settings from before an update are in the `UpdateBackups` folder mentioned
  above: `preferences.plist` (restore with `defaults import com.guitarherofree.ListeningTree preferences.plist`
  while the app is closed) and `app-data.tar.gz`.

The app then offers the newer version again; choose **Skip this version** if you
want to stay where you are.

## Troubleshooting

| Symptom | What to do |
|---|---|
| "Couldn't check for updates" | The message says why: no internet, or a missing, expired or too-limited token. `scripts/set-update-token.sh --check` tests the token |
| "You're up to date" but a release exists | The release is a pre-release or draft (ignored), or its tag isn't newer than the installed version, or it has no `.dmg` |
| The download fails its checksum | Try again; if it keeps failing, the uploaded file is broken: re-release |
| The update didn't install | See `~/Library/Logs/Listening Tree/updates.log`; the downloaded disk image stays in `~/Library/Application Support/ListeningTree/ListeningTree/update/` |
| "running from a temporary location" | macOS ran the app straight from Downloads. Move it into Applications, open it from there, update again |
| The app's own log | `~/Library/Application Support/ListeningTree/ListeningTree/logs/` |
