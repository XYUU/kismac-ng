#!/bin/sh

AIRPORT_PROG=`dirname "$0"`/AirPortMenu
LOCPATH=`/usr/bin/dirname "$0"`

/bin/sleep 2

"/sbin/kextunload" "$LOCPATH/WLanDriver.kext"

/bin/sleep 2

#seems to be a little unresponsive :/
if [ -e "/System/Library/Extensions/AppleAirPort.kext" ]; then
        /sbin/kextload "/System/Library/Extensions/AppleAirPort.kext"
fi
if [ -e "/System/Library/Extensions/AppleAirPort.kext" ]; then
        /sbin/kextload "/System/Library/Extensions/AppleAirPort.kext"
fi
if [ -e "/System/Library/Extensions/AppleAirPort.kext" ]; then
        /sbin/kextload "/System/Library/Extensions/AppleAirPort.kext"
fi


/bin/sleep 2

/sbin/ifconfig en1 up
"$AIRPORT_PROG" start

exit 0