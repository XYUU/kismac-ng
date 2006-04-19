#/bin/sh

rm -rf _inst
mkdir _inst

mkdir _inst/files
cp -R build/Deployment/GTDriver.kext _inst/files
cp install.command _inst
cp -R WiFiGUI/build/Deployment/WiFiGUI.app _inst/files
cp uninstall.command _inst
cp removeLoginItem.scpt _inst/files
cp addStartupItem.scpt _inst/files
#cp StartupParameters.plist _inst/files
#cp GTDriver _inst/files
touch .

cp bg.png _inst/files
./SetFile -a V _inst/files
./SetFile -a E _inst/*.command
