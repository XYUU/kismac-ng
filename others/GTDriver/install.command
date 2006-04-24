#!/bin/sh

echo "++++ Unloading old instances +++"
sudo killall WiFiGUI
sudo kextunload -b de.binaervarianz.driver.GTDriver 

DEST=/System/Library/Extensions/GTDriver.kext
FROM=`dirname "$0"`/files

echo "++++ Installing Driver ++++"
sudo rm -rf $DEST
sudo cp -r "$FROM/GTDriver.kext" $DEST
sudo chown -R root:wheel $DEST
sudo rm /System/Library/Extensions.kextcache
sudo kextcache -k /System/Library/Extensions
sudo killall -HUP kextd
sudo kextload $DEST

echo "++++ Installing Configuration Program ++++"
SDEST=/Library/StartupItems/GTDriver
sudo rm -rf $SDEST 
#sudo mkdir $SDEST
sudo cp -r "$FROM/WiFiGUI.app" $DEST/Contents/Resources
#sudo cp -r "$FROM/StartupParameters.plist" $SDEST
#sudo cp -r "$FROM/GTDriver" $SDEST
/usr/bin/osascript "$FROM/removeLoginItem.scpt"
cp "$FROM/addStartupItem.scpt" /tmp/addStartupItem.scpt
/usr/bin/osascript /tmp/addStartupItem.scpt
rm /tmp/addStartupItem.scpt

echo "++++ Starting Configuration Program ++++"
$DEST/Contents/Resources/WiFiGUI.app/Contents/MacOS/WiFiGUI&

echo
echo "++++++++++++++++++++++++++++++++"
echo "++++ Installation completed ++++"
echo "++++++++++++++++++++++++++++++++"
