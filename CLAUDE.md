# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MagicTap enables tap-to-click and double-tap-to-double-click on Apple Magic Mouse. It is a two-component macOS app:

1. **Zig backend** (`src/backend/src/main.zig`): Listens to multitouch events via the private `MultitouchSupport` framework, detects taps, and fires `CGEvent` mouse clicks.
2. **Swift menu bar client** (`src/client/`): A SwiftUI `MenuBarExtra` app that launches and manages the Zig backend process.

## Build & Run

### Monorepo (just)

```bash
just build             # 전체 빌드 (backend → client)
just test              # 전체 테스트
just release v0.2.0    # 릴리스 빌드
```

### Backend (Zig)

```bash
cd src/backend
NIX_CFLAGS_COMPILE="" zig build              # Build → src/backend/zig-out/bin/zig_my_mouse
NIX_CFLAGS_COMPILE="" zig build run          # Build and run directly
NIX_CFLAGS_COMPILE="" zig build test         # Run tests
```

Requires Zig ≥ 0.15.2 and `src/backend/local_frameworks/MultitouchSupport.framework` (private Apple framework, not committed).

### Swift Client

```bash
cd src/client
env -u SDKROOT swift run              # Build and launch menu bar app
```

Targets macOS 14+. The client expects the backend binary at `../../src/backend/zig-out/bin/zig_my_mouse` by default.

## Architecture

The backend (`src/backend/src/main.zig`) enumerates MT devices via `MTDeviceCreateList()`, skips built-in trackpads via `MTDeviceIsBuiltIn()`, and only attaches to Magic Mouse devices (PIDs `0x030D` and `0x0269`). It registers `touchCallback` as a `MTContactCallbackFunction` per device.

**Tap detection logic in `touchCallback`:**
- Track each finger by `identifier` in a fixed-size `finger_states[MAX_FINGERS]` array
- Cancel tracking if the finger moves beyond `TAP_MAX_MOVE` (0.045, normalized coords)
- On finger lift, if duration is within `[TAP_MIN_DURATION, TAP_MAX_DURATION]` (0.05s–0.5s), record as a tap candidate
- Double-tap: if a second tap arrives within `DOUBLE_TAP_MAX_INTERVAL` (0.30s), fire a double-click; otherwise flush as single click

`flushPendingSingleTap()` is called at the start of every callback frame to confirm a pending single click after the double-tap window expires.

The Swift client (`BackendController`) runs the Zig binary as a subprocess, pipes stdout/stderr to `NSLog`, and exposes `isRunning` state to the SwiftUI menu.

## macOS Permissions

The backend requires **Accessibility** permission to post `CGEvent` clicks. Depending on the environment, **Input Monitoring** may also be required. Grant these in System Settings → Privacy & Security for the Terminal or the built app.
