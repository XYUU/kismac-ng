#!/bin/bash

cd `dirname "$0"`

touch "./Sources/not public/WaveSecret.h"
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
xcodebuild -buildstyle Deployment