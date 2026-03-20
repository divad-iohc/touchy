# Touchy

`Touchy` is a small macOS menu bar app for remapping trackpad gestures.

Right now it supports:

- `3-Finger Click`
- `4-Finger Click`
- optional `Touch to Click` behavior for touch gestures
- global middle-click remapping

`Touchy` is experimental. It uses a private multitouch framework, so it is not App Store-safe and may break across macOS updates.

## Develop

The app lives in `mac-app/`.

Run it in development:

```bash
cd mac-app
swift run
```

Build a Finder-launchable app:

```bash
cd mac-app
./scripts/make-app.sh
```

That produces:

```text
mac-app/dist/Touchy.app
```

When testing:

- open `Touchy` from the menu bar
- grant Accessibility access
- allow Input Monitoring too if remapping still does not work
- watch for conflicts with built-in macOS trackpad gestures

## Contribute

Pull requests are welcome.

If you want to work on the app:

- keep changes focused
- test the menu bar flow and gesture remapping behavior
- update the UI and packaging scripts together when needed

GitHub Actions builds pull requests and tagged releases automatically.
