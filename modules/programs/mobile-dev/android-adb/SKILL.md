---
name: android-adb
description: >-
  Drive a physical Android phone over ADB with android-adb-* wrappers (unlock,
  lock, info, screenshot, clear, launch, log, grant). Use for on-device mobile
  app testing, agent phone loops, or remote device control when not at the desk.
---

# android-adb

Prefer these wrappers over raw `adb` for the workflows below. Use raw `adb` for one-offs (tap, swipe, install flags).

All commands honor `ANDROID_SERIAL` when multiple devices are attached.

## Session

```bash
android-adb-info                 # serial, model, battery, screen, keyguard, foreground
android-adb-unlock <pin>         # wake + PIN; no-op if already unlocked
android-adb-lock                 # KEYCODE_SLEEP
```

PIN comes from the user/env for the run — do not hardcode it in the skill or commit it.

## Test loop

```bash
android-adb-info
android-adb-unlock "$PIN"        # if keyguard=locked
android-adb-clear com.example.app
android-adb-grant com.example.app CAMERA RECORD_AUDIO
android-adb-launch com.example.app
android-adb-screenshot           # prints path; default $XDG_RUNTIME_DIR/android-adb/
# … interact (raw adb shell input …) …
android-adb-screenshot
android-adb-log com.example.app  # dump; add --follow or --lines N
android-adb-lock
```

## Commands

| Command | Purpose |
|---|---|
| `android-adb-info` | Preflight / which device |
| `android-adb-unlock <pin>` | Unlock keyguard |
| `android-adb-lock` | Sleep / lock |
| `android-adb-screenshot [path]` | PNG; prints host path |
| `android-adb-clear <pkg>` | `pm clear` |
| `android-adb-launch <target>` | package → launcher; `pkg/.Act` → component; `https://…` → VIEW |
| `android-adb-log <pkg> [--follow] [--lines N]` | logcat for package PID (default dump 200 lines) |
| `android-adb-grant <pkg> <perm…>` | Short names (`CAMERA`) → `android.permission.CAMERA` |

## Observe

After UI steps, **screenshot** (read the image) before guessing. Use **log** when the app crashes or misbehaves — keep dumps bounded (`--lines`), avoid unfiltered follow unless debugging live.

## Raw adb

Keep using `adb` (or `ANDROID_SERIAL=… adb`) for: `install`/`uninstall`, `input tap|swipe|text|keyevent`, `push`/`pull`, `reboot`. Do not invent parallel wrappers for those.
