#!/bin/sh

LOCPATH=`/usr/bin/dirname "$0"`

/usr/sbin/chown root:admin "$LOCPATH/"*.sh 
/bin/chmod 755 "$LOCPATH/"*.sh

/usr/sbin/chown root:admin "$LOCPATH/AirPortMenu"
/bin/chmod 755 "$LOCPATH/AirPortMenu"