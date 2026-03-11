#!/bin/bash
set -euo pipefail

trusted=$(swift -e 'import ApplicationServices; print(AXIsProcessTrusted())' 2> /dev/null || echo false)

echo "Atlas UI automation preflight"
echo "============================"
echo "Accessibility trusted for current process: $trusted"

if [[ "$trusted" != "true" ]]; then
    cat << 'MSG'
✗ UI automation is currently blocked by macOS Accessibility / automation permissions.

To unblock local XCUITest on this machine:
1. Open System Settings
2. Privacy & Security -> Accessibility
3. Allow the terminal app you use to run `xcodebuild` (Terminal / iTerm / Warp / etc.)
4. Also allow Xcode if you run tests from Xcode directly
5. Re-run the minimal repro:
   xcodebuild test -project Testing/XCUITestRepro/XCUITestRepro.xcodeproj -scheme XCUITestRepro -destination 'platform=macOS'
MSG
    exit 1
fi

echo "✓ Current process is trusted for Accessibility APIs"
