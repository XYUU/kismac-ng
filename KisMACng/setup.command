#!/bin/bash

touch "./Sources/not public/WaveSecret.h"
mkdir "./Subprojects/files" 2>/dev/null
cd "./Subprojects/files"
rm -rf *.framework 2>/dev/null
cd ..

cd MACJack
xcodebuild
cd ../Viha
xcodebuild
cd ../AiroJack
xcodebuild
cd ../BIGL
xcodebuild
cd ../BIGeneric
xcodebuild
cd ../..

