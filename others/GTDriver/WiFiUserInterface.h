/*
        
        File:			WiFiUserInterface.h
        Program:		GTDriver
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		GTDriver is a free driver for PrismGT based cards under OS X.
                
        This file is part of GTDriver.

    GTDriver is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    GTDriver is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with GTDriver; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#define MAX_BSS_COUNT   20
#define MAX_SSID_LENGTH 32

#define kWiFiUserClientNotify     0xdeadbeef
#define kWiFiUserClientMap        0xdeadface

typedef enum WLUCMethods {
    kWiFiUserClientOpen,                // kIOUCScalarIScalarO, 0, 0
    kWiFiUserClientClose,               // kIOUCScalarIScalarO, 0, 0
    kWiFiUserClientGetLinkSpeed,        // kIOUCScalarIScalarO, 0, 1
    kWiFiUserClientGetConnectionState,  // kIOUCScalarIScalarO, 0, 1
    kWiFiUserClientGetFrequency,        // kIOUCScalarIScalarO, 0, 1
    kWiFiUserClientSetFrequency,        // kIOUCScalarIScalarO, 0, 1
    kWiFiUserClientSetSSID,             // kIOUCScalarIStructI, 0, 1
    kWiFiUserClientSetWEPKey,           // kIOUCScalarIStructI, 0, 1
    kWiFiUserClientGetScan,             // kIOUCScalarIStructO, 0, 1
    kWiFiUserClientSetMode,             // kIOUCScalarIScalarO, 1, 0
    kWiFiUserClientLastMethod,
} WLUCMethod;

typedef enum {
    stateIntializing = 0,
    stateCardEjected,
    stateSleeping,
    stateDisabled,
    stateDisconnected,
    stateDeauthenticated,
    stateDisassociated,
    stateAuthenicated,
    stateAssociated,
} wirelessState;

typedef enum {
    modeNone = 0,
    modeIBSS,
    modeClient,
    modeHostAP,
    modeMonitor,
} wirelessMode;

typedef struct {
    UInt8   ssidLength;
    UInt8   ssid[MAX_SSID_LENGTH];
    UInt8   address[6];
    UInt16  cap;
    UInt8   active;
} bssItem;