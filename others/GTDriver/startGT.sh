#!/bin/bash

cd build
sudo chown -R root:wheel GTDriver.kext
sudo kextunload GTDriver.kext
sudo kextload GTDriver.kext
sudo chown -R mick:mick GTDriver.kext
