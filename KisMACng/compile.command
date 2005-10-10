#!/bin/bash

cd `dirname "$0"`

mkdir "./build/KisMACUnitTest.bundle/Contents/Frameworks" 2>/dev/null
cd UnitTest
ln -s "../build/KisMACUnitTest.bundle/Contents/Frameworks" . 2>/dev/null
tar xjf UnitKit.tbz 2>/dev/null
cd ..

val=`svnversion -n .`
sed -e "s/\\\$Revision.*\\\$/\\\$Revision: $val\\\$/" Resources/Info.plist.templ > Resources/Info.plist
sed -e "s/\\\$Revision.*\\\$/\\\$Revision: $val\\\$/" Resources/Strings/English.lproj/InfoPlist.strings.templ > Resources/Strings/English.lproj/InfoPlist.strings

touch "./Sources/not public/WaveSecret.h"
touch "./Sources/WindowControllers/CrashReportController.m"
mkdir "./Subprojects/files" 2>/dev/null
cd "./Subprojects/files"
rm -rf *.framework 2>/dev/null
cd ..

cd MACJack
xcodebuild -configuration Deployment
cd ../VihaDriver
xcodebuild -configuration Deployment
cd ../AtheroJack
xcodebuild -configuration Deployment
cd ../AiroJack
xcodebuild -configuration Deployment
cd ../BIGL
xcodebuild -configuration Deployment
cd ../BIGeneric
xcodebuild -configuration Deployment
cd ../AirPortMenu
xcodebuild -configuration Deployment
cd ../KisMAC\ Installer
xcodebuild -configuration Deployment

cd ../..
xcodebuild -target KisMAC -configuration Deployment
