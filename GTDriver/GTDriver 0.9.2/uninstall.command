#!/bin/sh

echo "++++ Killing Process & Driver ++++"
sudo killall WiFiGUI
sudo kextunload -b de.binaervarianz.driver.GTDriver 

DEST=/System/Library/Extensions/GTDriver.kext

echo "++++ Removing Driver ++++"
sudo rm -rf $DEST
sudo rm /System/Library/Extensions.kextcache
sudo kextcache -k /System/Library/Extensions
sudo killall -HUP kextd

echo "++++ Removing Startup Item ++++"
SDEST=/Library/StartupItems/GTDriver
sudo rm -rf $SDEST 

echo
echo "+++++++++++++++++++++++++++"
echo "++++ Removal Completed ++++"
echo "+++++++++++++++++++++++++++"
