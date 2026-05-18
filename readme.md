
# Adzan Prayer Times Plasma Widget

KDE Plasma widget (plasmoid) to display Islamic prayer times for a configurable address.

The widget shows:
- Next prayer in the panel (or countdown, based on settings)
- Full daily prayer schedule in popup
- Gregorian and Hijri date
- Manual refresh button

## Project Status

- Target: KDE Plasma 5 (QML plasmoid structure)
- API provider: AlAdhan Prayer Times API
- Widget plugin id: `com.github.reeganaga.kdeadzan`

## Features

- Fetch prayer times by address
- Highlight next prayer in the full schedule
- Optional countdown text for next prayer
- Daily auto-refresh at configurable hour (default: 09:00)
- Manual refresh from popup
- Automatic refresh when address is changed in settings
- Fullscreen overlay notification with audio at prayer time
- Configurable pre-prayer preparation alert with beep sound

## Requirements

- Linux desktop with KDE Plasma
- `curl` available in system PATH (used by the plasmoid for network requests)
- `QtGraphicalEffects` QML module (for the overlay blur effect; included in most Plasma 5 installs)

Optional for audio:
- `mpv` or `ffplay` — for playing a custom athan MP3 (`~/.local/share/adzan/athan.mp3`)
- `paplay` — PulseAudio player used as fallback for system sounds
- `canberra-gtk-play` — alternative fallback beep source

Optional development tools:
- `plasmoidviewer`
- `plasmapkg2` or `kpackagetool5`

## Install and Run Locally

From this folder:

1. Quick run in viewer:

```bash
plasmoidviewer -a .
```

2. Install to your widgets:

```bash
plasmapkg2 --type plasmoid --install .
```

If already installed and updating:

```bash
plasmapkg2 --type plasmoid --upgrade .
```

If your distro uses `kpackagetool5` instead:

```bash
kpackagetool5 --type Plasma/Applet --install .
```

After install, add the widget from Plasma widgets list.

## Configuration

Open widget settings and use the **General** tab.

Available config keys:

1. `address` (string)
	- Example: `Yogyakarta, Indonesia`
	- Used to fetch prayer times for your location.

2. `updateHour` (int, 0-23)
	- Default: `9`
	- The widget auto-fetches once daily when local time reaches this hour and minute `00`.

3. `showCountdown` (bool)
	- Default: `false`
	- If enabled, panel text shows countdown to next prayer.
	- If disabled, panel text shows next prayer name and time.

4. `minutesBefore` (int, 0-30)
	- Default: `5`
	- How many minutes before each prayer to show the preparation overlay and play a beep.
	- Set to `0` to disable the pre-prayer alert (only the at-time notification fires).

5. `enableOverlayNotification` (bool)
	- Default: `true`
	- Toggles the fullscreen overlay window for both the preparation and at-time notifications.
	- When disabled, any currently visible overlay is dismissed immediately.

## How API Works in This Project

Reference:
- https://aladhan.com/prayer-times-api#tag/daily-prayer-times/GET/timingsByAddress/{date}

Flow used by the widget:

1. Build date as `DD-MM-YYYY`.
2. Build request URL:

```text
https://api.aladhan.com/v1/timingsByAddress/{DD-MM-YYYY}?address={ENCODED_ADDRESS}&method=3&shafaq=general&school=0&midnightMode=0&latitudeAdjustmentMethod=1&calendarMethod=UAQ&iso8601=false
```

3. Execute request with `curl` through Plasma executable data engine.
4. Parse JSON response (`code === 200`).
5. Read `data.timings`, `data.date.readable`, and `data.date.hijri`.
6. Compute and update next prayer and optional countdown.

Why `curl` is used:
- In Plasma shell context, QML `XMLHttpRequest` can fail on HTTPS/SSL in some setups.
- `curl` is more reliable across systems for this plasmoid.

## How to Change Configuration Behavior (Contributor)

Main config schema:
- `contents/config/main.xml`

Settings UI:
- `contents/ui/configGeneral.qml`

Usage in widget runtime:
- `contents/ui/main.qml`

Typical change example (add new setting):

1. Add `<entry>` in `contents/config/main.xml`.
2. Expose `cfg_*` alias in `contents/ui/configGeneral.qml`.
3. Read setting from `plasmoid.configuration.*` in `contents/ui/main.qml`.
4. React to changes in `Connections { target: plasmoid.configuration ... }` if needed.

## Development Notes

- Compact representation: panel text and click-to-open popup.
- Full representation: date header, prayer rows, status, refresh button.
- Prayer order used in UI:
  - Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- If all prayer times passed for today, widget falls back to next day Fajr countdown logic.

## Publish to KDE Store (Pling)

Before publishing:

1. Ensure metadata is complete in `metadata.desktop`:
	- Name, version, website, author, email, category.
2. Add repository docs:
	- This README
	- `LICENSE` file
	- `CHANGELOG.md` (recommended)
3. Test install and upgrade on a clean user session.
4. Verify panel mode and popup mode both work.

Packaging tip:

```bash
zip -r adzan-plasmoid.zip .
```

Upload the zip to KDE Store under Plasma Widget category.

## Contributing

Contributions are welcome.

### Setup

1. Fork the repository.
2. Create a feature branch.
3. Run and test with `plasmoidviewer`.
4. Submit a pull request with clear description and screenshots/GIF if UI changed.

### Contribution Guidelines

- Keep Plasma 5 compatibility unless a migration plan is proposed.
- Keep config keys backward-compatible when possible.
- Document any new setting in this README.
- For API parameter changes, explain rationale in PR.
- Keep UI text translatable (`i18n(...)`).

## Troubleshooting

1. `Network error: cannot reach server`
	- Check internet connection.
	- Verify `curl` is installed.
	- Test endpoint manually with the same address.

2. `Parse error`
	- API may return unexpected content or temporary upstream error.
	- Retry using refresh button.

3. No update at expected time
	- Auto-fetch runs at configured hour when minute is `00`.
	- Keep Plasma session running at that time.

## Roadmap Ideas

- Add calculation method selection in settings
- Add timezone override
- Add per-prayer adjustment offsets
- Add localization for prayer names