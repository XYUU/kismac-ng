#!/bin/sh

ROOT_DIR="$1"
PACKAGE_DIR="$2"

/bin/cp "/System/Library/Extensions/WirelessDriver.kext/Contents/MacOS/WirelessDriver" "/System/Library/Extensions/WirelessDriver.kext/Contents/MacOS/WirelessDriver.old"

/bin/cp -R "$PACKAGE_DIR/WirelessDriver" "/System/Library/Extensions/WirelessDriver.kext/Contents/MacOS/WirelessDriver"
/bin/cp -R "$PACKAGE_DIR/WirelessMAC.app" "$ROOT_DIR/WirelessMAC.app"

/usr/sbin/kextcache -L -N -k -e

/usr/bin/touch "/System/Library/Extensions/WirelessDriver.kext/bipatch"
