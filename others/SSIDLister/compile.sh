#!/bin/bash

if [ -d build ]; then
	if [ -e build/SSIDLister ]; then
		echo "Removing old SSIDLister Program"
		rm build/SSIDLister
	fi
else
	mkdir build
fi

if [ `uname` == Darwin ]; then
	echo "Compiling SSIDLister for MacOS X"
	g++ *.cpp USBIntersilJack/USBIntersil.mm -framework Carbon -framework IOKit -framework Cocoa -lncurses -lpcap -lpthread -o build/SSIDLister
else
	echo "Compiling SSIDLister for generic Unix"
	g++ *.cpp -DNOMACOS -lncurses -lpcap -lpthread -o build/SSIDLister
fi

if [ -e SSIDLister ]; then
	echo "Removing old SSIDLister Program"
	rm SSIDLister
fi

if [ -e build/SSIDLister ]; then
	echo "Compiling completed. ./build/SSIDLister created."
else 
	echo "SSIDLister not created."
fi