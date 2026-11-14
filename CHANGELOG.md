# Changelog

Release notes for Listening Tree, newest first. When you publish a version,
`scripts/release.sh` uses its section below as the GitHub release notes, and the
app shows those notes in its update window, so write them for the person
updating: what's new, what changed, anything to watch out for.

Start each section with `## [x.y.z]` (a date after it is optional). Markdown
lists, **bold** and links show up nicely in the app.

## [Unreleased]

## [0.1.1] - 2026-11-14

A small update to confirm that in-app updates work.

- No changes to recording, editing or your settings. If this window appeared and the update installs, the update system is working.
- The guides now explain how to clone the private repository on a new Mac.

## [0.1.0] - 2026-11-14

The first version of Listening Tree: Audacity 4.0.2 under its own name, with updates from GitHub.

- Based on **Audacity 4.0.2**. Recording, editing, effects and export work as in Audacity 4.0.2.
- **In-app updates:** Listening Tree checks this project's GitHub releases once a day (and whenever you choose **Help › Check for update**), shows what's new, and installs the update when you say so. Projects and settings stay as they are, and settings are backed up before each update.
- Keeps its own settings, separate from any copy of Audacity on the same Mac.
- Anonymous usage statistics (sent to audio.com by Audacity) are turned off.
