#!/bin/bash

cd `dirname "$0"`

mkdir "./build/KisMACUnitTest.bundle/Contents/Frameworks" 2>/dev/null
cd UnitTest
ln -s "../build/KisMACUnitTest.bundle/Contents/Frameworks" . 2>/dev/null
tar xjf UnitKit.tbz 2>/dev/null
cd ..

touch "./Sources/not public/WaveSecret.h"
touch "./Sources/WindowControllers/CrashReportController.m"
mkdir "./Subprojects/files" 2>/dev/null
cd "./Subprojects/files"
rm -rf *.framework 2>/dev/null
cd ..

cd MACJack
xcodebuild -buildstyle Deployment
cd ../VihaDriver
xcodebuild -buildstyle Deployment
cd ../AiroJack
xcodebuild -buildstyle Deployment
cd ../BIGL
xcodebuild -buildstyle Deployment
cd ../BIGeneric
xcodebuild -buildstyle Deployment
cd ../..
xcodebuild -target KisMAC -buildstyle Deployment
