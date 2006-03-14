#!/bin/bash

configuration=Deployment

echo "Checking for required enviroment..."
if ! [ -x /usr/bin/tar ]; then
	echo "/usr/bin/tar not found! Make sure you installed the BSD subsystem!"
	exit 1
fi

if echo $0 | grep " " > /dev/null; then
	echo "KisMAC source path contains a space character. This will lead to problems!"
	exit 1
fi

cd "`dirname "$0"`"

echo "Decompressing UnitTest bundle..."
mkdir "./build/KisMACUnitTest.bundle/Contents/Frameworks" 2>/dev/null
cd UnitTest
ln -s "../build/KisMACUnitTest.bundle/Contents/Frameworks" . 2>/dev/null
tar -xjf UnitKit.tbz 2>/dev/null
cd ..

echo "Decompressing Growl framework..."
cd Resources
tar -xzf growl.tgz
cd ..

echo "Determine Subversion Revision..."
val=`svnversion -n .`
sed -e "s/\\\$Revision.*\\\$/\\\$Revision: $val\\\$/" Resources/Info.plist.templ > Resources/Info.plist
sed -e "s/\\\$Revision.*\\\$/\\\$Revision: $val\\\$/" Resources/Strings/English.lproj/InfoPlist.strings.templ > Resources/Strings/English.lproj/InfoPlist.strings

echo "Preparing Enviroment..."
if [ -f compile.log ]; then
  rm compile.log
fi
touch "./Sources/not public/WaveSecret.h"
touch "./Sources/WindowControllers/CrashReportController.m"
mkdir "./Subprojects/files" 2>/dev/null
cd "./Subprojects/files"
rm -rf *.framework 2>/dev/null
cd ..

echo -n "Building MACJack driver... "
cd MACJack
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
	exit 1
else
	echo "ok"
fi

echo -n "Building Viha driver... "
cd ../VihaDriver
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

echo -n "Building AtheroJack driver... "
cd ../AtheroJack
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

echo -n "Building AiroJack driver... "
cd ../AiroJack
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

echo -n "Building binaervarianz openGL framework... "
cd ../BIGL
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

echo -n "Building generic binaervarianz framework... "
cd ../BIGeneric
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

cd ../AirPortMenu
echo -n "Building AirPortMenu tool... "
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

cd ../KisMACInstaller
echo -n "Building KisMAC installer application... "
if ! xcodebuild -configuration $configuration >> ../../compile.log; then
        exit 1
else
        echo "ok"
fi

echo -n "Building KisMAC main application... "
cd ../..
if ! xcodebuild -target KisMAC -configuration $configuration >> compile.log; then
        exit 1
else
        echo "ok"
fi

