#!/usr/bin/env bash
# ============================================================
#  PrankLock — Installer
#  https://github.com/FabricioDevRDC/prank-lock
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="PrankLock"
APP_BUNDLE="$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_BUNDLE"
BINARY_SRC="$REPO_DIR/.build/release/PrankLock"
PLIST_SRC="$REPO_DIR/scripts/Info.plist"
ICON_SRC="$REPO_DIR/Sources/PrankLock/Resources/AppIcon.icns"

# ── colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✖ $*${RESET}"; exit 1; }

echo ""
echo -e "${BOLD}🔒  PrankLock Installer${RESET}"
echo "    The fun way to enforce the lock-your-Mac policy."
echo ""

# ── 1. Check macOS version ────────────────────────────────────
info "Checking macOS version…"
MACOS_VER=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 13 ]]; then
    error "PrankLock requires macOS 13 Ventura or later. You have $MACOS_VER."
fi
success "macOS $MACOS_VER — OK"

# ── 2. Check Swift ────────────────────────────────────────────
info "Checking Swift…"
if ! command -v swift &>/dev/null; then
    warn "Swift not found. Installing Xcode Command Line Tools…"
    xcode-select --install
    echo "  Re-run this script after installation completes."
    exit 0
fi
SWIFT_VER=$(swift --version 2>&1 | head -1)
success "Swift found: $SWIFT_VER"

# ── 3. Build ──────────────────────────────────────────────────
info "Building PrankLock (release)…"
cd "$REPO_DIR"
swift build -c release 2>&1 | grep -E "^(Build complete|error:|warning: )" || true

if [[ ! -f "$BINARY_SRC" ]]; then
    error "Build failed — binary not found at $BINARY_SRC"
fi
success "Build complete"

# ── 4. Kill existing instance ─────────────────────────────────
if pgrep -x PrankLock &>/dev/null; then
    info "Stopping running PrankLock instance…"
    pkill -x PrankLock || true
    sleep 0.5
fi

# ── 5. Assemble .app bundle ───────────────────────────────────
info "Installing to $APP_PATH…"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BINARY_SRC" "$APP_PATH/Contents/MacOS/PrankLock"
chmod +x "$APP_PATH/Contents/MacOS/PrankLock"

# Copy icon
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

# Write Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>         <string>PrankLock</string>
    <key>CFBundleIdentifier</key>         <string>com.fabriciozacarias.pranklock</string>
    <key>CFBundleName</key>               <string>PrankLock</string>
    <key>CFBundleDisplayName</key>        <string>PrankLock</string>
    <key>CFBundleVersion</key>            <string>1.0.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0.0</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>13.0</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>PrankLock needs Accessibility access to monitor mouse and keyboard events during prank mode.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>PrankLock needs Automation access to force-quit blocked apps while locked.</string>
</dict>
</plist>
PLIST

# Clear quarantine so macOS doesn't block it
xattr -cr "$APP_PATH"
success "Installed to $APP_PATH"

# ── 6. Launch ─────────────────────────────────────────────────
info "Launching PrankLock…"
open "$APP_PATH"
sleep 1

echo ""
echo -e "${BOLD}${GREEN}🎉  PrankLock is installed and running!${RESET}"
echo ""
echo -e "  ${BOLD}What to do next:${RESET}"
echo "  1. Look for the 🔒 icon in your menu bar."
echo "  2. Click it → \"Activate PrankLock…\""
echo "  3. Record your secret unlock combo (modifier keys)."
echo "  4. Click Activate and step away."
echo "  5. When you return: hold your combo for 2 seconds."
echo ""
echo -e "  ${BOLD}Permissions required (macOS will prompt):${RESET}"
echo "  • Accessibility  — for mouse/keyboard monitoring"
echo "  • Automation     — for force-quitting blocked apps"
echo ""
echo -e "  ${CYAN}Repo: https://github.com/FabricioDevRDC/prank-lock${RESET}"
echo ""

# ── 7. Remind about Accessibility ────────────────────────────
if ! osascript -e 'tell application "System Events" to return name of every process' &>/dev/null; then
    echo ""
    warn "Accessibility permission needed."
    echo "  Open: System Settings → Privacy & Security → Accessibility"
    echo "  Add PrankLock from $INSTALL_DIR and enable it."
    echo ""
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
