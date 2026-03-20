# Touchy

`Touchy` is an experimental macOS menu bar utility for remapping:

- 3-finger click
- 4-finger click

The active Swift project lives in `mac-app/`.

## Why Swift

Swift is the pragmatic choice because the UI shell, event tap integration, and macOS permissions flow all live on the AppKit side.

## Current scope

This version is intentionally a menu bar utility:

- It runs without a Dock icon.
- It exposes a settings window from the macOS menu bar.
- It lets you assign a basic action to `3-Finger Click` and `4-Finger Click`.
- It includes a `Touch to Click` toggle so touch can reuse the click actions.
- If `Touch to Click` is off, you can assign separate actions to `3-Finger Touch` and `4-Finger Touch`.
- It attempts to remap those clicks globally, including in other apps.

## Important macOS limitation

This app uses a private multitouch framework to detect global trackpad finger counts. That means it is experimental, not App Store-safe, and may break across macOS updates. macOS may also reserve some three-finger or four-finger gestures for Mission Control, App Expose, desktop switching, and related system features. For reliable testing, you may need to disable conflicting trackpad gestures in System Settings.

## Run

For development from Terminal:

```bash
cd mac-app
swift run
```

When the app is running:

- Look for `Touchy` in the macOS menu bar.
- Open `Settings...` from the menu bar item.
- Grant Accessibility access when prompted.
- If global remapping still does not work, also allow Input Monitoring in System Settings.
- Set `3-Finger Click` to `Middle Click`.
- Test in another app, such as closing a browser tab with middle click.

## Build A Normal App Bundle

To create a Finder-launchable app:

```bash
cd mac-app
./scripts/make-app.sh
```

That produces:

```text
mac-app/dist/Touchy.app
```

You can then open it from Finder or with:

```bash
open "dist/Touchy.app"
```

## Release On GitHub

This repo includes a GitHub Actions workflow at `.github/workflows/release.yml`.

To publish a downloadable release:

```bash
git tag v0.1.0
git push origin main --tags
```

That workflow:

- builds the macOS app on a GitHub-hosted macOS runner
- packages `Touchy.app` as a zip archive
- generates a SHA-256 checksum
- creates or updates the matching GitHub Release and uploads both files

You can also run the workflow manually from the GitHub Actions tab to produce a build artifact without publishing a tagged release.

## Pull Request Builds

This repo also includes `.github/workflows/pull-request.yml`.

That workflow runs on pull requests to `main`, on pushes to `main`, and on manual dispatch. It builds the app, packages it as a zip, and uploads the archive plus checksum as workflow artifacts so changes can be validated before a tagged release.
