
# Changelog

## v.1.0.0 — 2026-05-18

### Added
- **Fullscreen overlay notification**: at prayer time (and optionally N minutes before), a fullscreen window covers all connected screens showing the prayer name, a countdown, and a Dismiss button. The overlay features a blurred gradient backdrop with a semi-transparent dark tint (requires `QtGraphicalEffects`).
- **Pre-prayer preparation alert** (`minutesBefore`): configurable offset (0–30 min, default 5) that triggers a preparation notification before each prayer with a short beep sound.
- **Audio playback**: plays a system beep before prayer (via `paplay` or `canberra-gtk-play`) and plays athan audio at prayer time. Looks for `~/.local/share/adzan/athan.mp3` first; falls back to a system alarm sound. Supported players: `mpv`, `ffplay`, `paplay`.
- Multi-screen support: the overlay window is instantiated for every unique screen geometry detected via `Qt.application.screens`.
- Per-day deduplication of notification events so each prayer triggers only once per day.
- A 10-second polling timer for keeping the overlay countdown label in sync in addition to the existing per-minute timer.
- Config change handlers for `minutesBefore` and `enableOverlayNotification` (resets triggered events or dismisses the overlay immediately).

### Changed
- Refresh button is now wrapped in a `RowLayout` to accommodate future action buttons.
- `Component.onCompleted` now also calls `refreshOverlayScreens()` before fetching prayer times.
