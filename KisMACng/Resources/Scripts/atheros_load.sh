#!/bin/sh

LOCPATH=`/usr/bin/dirname "$0"`

DEST="/System/Library/Extensions/AtherosHAL.kext"

if [ -e "/System/Library/Extensions/OMI_80211g.kext" ]; then
    if /usr/sbin/kextstat -b com.orangeware.iokit.OMI_80211g | /usr/bin/grep --quiet com.orangeware.iokit.OMI_80211g ; then
        /usr/bin/killall WirelessConfigurationService
        /usr/bin/killall OMI_80211g_App
        /bin/sleep 1
        /sbin/kextunload "/System/Library/Extensions/OMI_80211g.kext"
        /bin/sleep 2
    fi
fi

/usr/sbin/chown -R root:wheel "$LOCPATH/AtherosHAL.kext"
/bin/chmod -R g-w "$LOCPATH/AtherosHAL.kext"
/bin/chmod -R o-wrx "$LOCPATH/AtherosHAL.kext"

if [ ! -e $DEST ]; then
    /bin/cp -r "$LOCPATH/AtherosHAL.kext" $DEST
    /usr/sbin/chown -R root $DEST
    /usr/bin/chgrp -R wheel $DEST
    /bin/rm /System/Library/Extensions.kextcache
    /usr/sbin/kextcache -k /System/Library/Extensions
    KEXTD=`/bin/ps -x -Uroot | /usr/bin/grep kextd | /usr/bin/awk '{print $1}'`
    /bin/kill -HUP $KEXTD
fi
/sbin/kextload $DEST

DEST="/System/Library/Extensions/IO80211Family.kext"

/usr/sbin/chown -R root:wheel "$LOCPATH/IO80211Family.kext"
/bin/chmod -R g-w "$LOCPATH/IO80211Family.kext"
/bin/chmod -R o-wrx "$LOCPATH/IO80211Family.kext"

if [ ! -e $DEST ]; then
    /bin/cp -r "$LOCPATH/IO80211Family.kext" $DEST
    /usr/sbin/chown -R root $DEST
    /usr/bin/chgrp -R wheel $DEST
    /bin/rm /System/Library/Extensions.kextcache
    /usr/sbin/kextcache -k /System/Library/Extensions
    KEXTD=`/bin/ps -x -Uroot | /usr/bin/grep kextd | /usr/bin/awk '{print $1}'`
    /bin/kill -HUP $KEXTD
fi
/sbin/kextload $DEST

/bin/sleep 1

/usr/sbin/chown -R root:wheel "$LOCPATH/AtherosWifi.kext"
/bin/chmod -R g-w "$LOCPATH/AtherosWifi.kext"
/bin/chmod -R o-wrx "$LOCPATH/AtherosWifi.kext"

/sbin/kextload "$LOCPATH/AtherosWifi.kext"
