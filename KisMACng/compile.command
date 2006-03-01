#!/bin/bash

configuration=Deployment

cd "`dirname "$0"`"

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
xcodebuild -configuration $configuration
cd ../VihaDriver
xcodebuild -configuration $configuration
cd ../AtheroJack
xcodebuild -configuration $configuration
cd ../AiroJack
xcodebuild -configuration $configuration
cd ../BIGL
xcodebuild -configuration $configuration
cd ../BIGeneric
xcodebuild -configuration $configuration
cd ../AirPortMenu
xcodebuild -configuration $configuration
cd ../KisMAC\ Installer
xcodebuild -configuration $configuration

cd ../..
xcodebuild -target KisMAC -configuration $configuration
