#/bin/sh

rm -rf _inst
mkdir _inst

mkdir _inst/files
cp -R build/GTDriver.kext _inst/files
cp install.command _inst
cp -R WiFiGUI/build/WiFiGUI.app _inst/files
cp uninstall.command _inst
ditto --rsrc addStartupItem.app _inst/files
ditto --rsrc removeLoginItem.app _inst/files
#cp StartupParameters.plist _inst/files
#cp GTDriver _inst/files
touch .

cp bg.png _inst/files
./SetFile -a V _inst/files
./SetFile -a E _inst/*.command
