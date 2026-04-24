# PrankLock 🔒😈

> The fun way to enforce the "lock your Mac" policy at the office.

PrankLock is a **safe, open-source macOS menu-bar app** that turns an unlocked Mac into a prank minefield. Activate it before you step away — if a coworker touches your Mac without permission, chaos ensues. Enter your password to restore order.

**No data is stolen. No files are deleted. No real damage is done. Just vibes.**

---

## Features

### Core behavior
| Feature | Light | Chaos | Evil |
|---------|:-----:|:-----:|:----:|
| Warning overlay banner | ✅ | ✅ | ✅ |
| Toast popups ("Nice try 👀") | ✅ | ✅ | ✅ |
| Sound effects on every click & keypress (all apps) | ✅ | ✅ | ✅ |
| App blocking (force-quit on launch) | ✅ | ✅ | ✅ |
| Mouse cursor flees the pointer (blocked apps only) | ❌ | ✅ | ✅ |
| Windows minimize on click (blocked apps only) | ❌ | ✅ | ✅ |
| Keyboard scramble toasts (all apps) | ❌ | ✅ | ✅ |
| Clipboard hijack — paste returns a taunt | ❌ | ✅ | ✅ |
| Random window teleporting (blocked apps only) | ❌ | ✅ | ✅ |
| Windows bounce to new positions every 45s | ❌ | ✅ | ✅ |
| Mac speaks taunts aloud every ~45s | ❌ | ❌ | ✅ |
| Fake "macOS Update" loading screen | ❌ | ❌ | ✅ |

### Prank targeting
- **Sound + toast** fire on every click and keypress across **all apps** while locked
- **Cursor flee, minimize, teleport** only trigger when clicking inside a **blocked app**
- **Clipboard hijack** replaces clipboard text with a taunt on keypress (throttled to once every 5s)
- **Voice taunts** — macOS `say` reads a line aloud every ~45s in Evil mode

### Security & smart features
- **Auto-lock** after configurable inactivity period
- **Real macOS lock** (⌘⌃Q) after N failed unlock attempts
- **Attempt log** — timestamp + action for everything that happened while locked
- **Silent mode** — no sounds for open-plan offices
- **Quick activate** — menu bar with keyboard shortcut

### Customization
- Prank intensity: **Light / Chaos / Evil**
- Custom prank messages (shown as toasts and in the overlay)
- Blocked app list by Bundle ID
- Per-slot sound picker — choose which system sound plays on click, keypress, and window bounce
- Choose how many wrong attempts trigger real macOS lock

---

## Requirements
- macOS 13 Ventura or later
- **Accessibility permission** (for global mouse/keyboard monitoring and cursor warping)
- **Automation permission** (for force-quitting blocked apps)

---

## Installation

### From source (Xcode)
```bash
git clone https://github.com/FabricioDevRDC/prank-lock
open prank-lock
# Build & run from Xcode
```

### Swift CLI build (no Xcode required)
```bash
cd prank-lock
swift build -c release
cp -R .build/release/PrankLock.app ~/Applications/
open ~/Applications/PrankLock.app
```

---

## How to use

1. **Open PrankLock** — it lives in your menu bar as a 🔒 icon.
2. Click **Activate PrankLock…**, choose intensity, set a PIN or passphrase.
3. Click **Activate** and step away. PrankLock is armed.
4. When you return, click the menu bar icon and enter your password to unlock.

---

## Permissions

PrankLock will ask for:

| Permission | Why |
|-----------|-----|
| Accessibility | Global event monitoring (mouse, keyboard) and cursor warping |
| Automation | Force-quitting blocked apps |

You can grant these in **System Settings → Privacy & Security**.

---

## Architecture

```
PrankLock/
├── Package.swift
└── Sources/PrankLock/
    ├── main.swift              # App entry, AppDelegate, menu bar
    ├── PrankStore.swift        # State, password, settings, attempt log
    ├── LockCoordinator.swift   # Orchestrates engine + blocker + inactivity
    ├── PrankEngine.swift       # All active prank behaviors
    ├── Pranks/
    │   └── Sounds.swift        # NSSound wrappers + system sound scanner
    ├── Security/
    │   ├── AppBlocker.swift    # Force-quits blocked apps on launch
    │   └── InactivityWatcher.swift  # Auto-lock after idle
    └── Views/
        ├── ActivateView.swift  # PIN entry + intensity picker
        ├── UnlockView.swift    # Password unlock screen
        ├── PreferencesView.swift
        ├── ToastView.swift     # Floating prank message
        └── FakeLoadingView.swift  # Evil-mode fake OS update screen
```

**Stack:** SwiftUI + AppKit, Swift Package Manager, no external dependencies.

---

## Contributing

PRs welcome! Ideas for new gags, sound packs, themes, or new prank behaviors.

Please keep it fun, not harmful. No screen-destroying effects, no data access, no persistence between pranks.

---

## License

MIT License — see [LICENSE](LICENSE).
