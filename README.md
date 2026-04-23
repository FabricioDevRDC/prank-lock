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
| Funny sound effects | ✅ | ✅ | ✅ |
| App blocking (force-quit on launch) | ✅ | ✅ | ✅ |
| Mouse cursor flees the pointer | ❌ | ✅ | ✅ |
| Windows minimize on click | ❌ | ✅ | ✅ |
| Keyboard scramble (injects random chars) | ❌ | ✅ | ✅ |
| Random window teleporting | ❌ | ✅ | ✅ |
| Windows bounce to new positions every 45s | ❌ | ✅ | ✅ |
| Fake "macOS Update" loading screen | ❌ | ❌ | ✅ |

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
- Choose how many wrong attempts trigger real macOS lock

---

## Requirements
- macOS 13 Ventura or later
- **Accessibility permission** (for global mouse/keyboard monitoring and cursor warping)
- **Automation permission** (for force-quitting blocked apps)
- Optional: Camera permission for webcam snapshots on wrong passwords

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
cp .build/release/PrankLock /Applications/PrankLock
open /Applications/PrankLock
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
| Camera (optional) | Webcam snapshot on failed unlock attempt |

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
    │   └── Sounds.swift        # NSSound wrappers
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
