#!/bin/sh

LOCPATH=`/usr/bin/dirname "$0"`

/sbin/ifconfig en1 down
"$LOCPATH/AirPortMenu" stop
