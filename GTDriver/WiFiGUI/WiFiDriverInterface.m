/*
        
        File:			WiFiDriverInterface.m
        Program:		WiFiGUI
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
#import "WiFiDriverInterface.h"

@implementation WiFiDriverInterface

+ (bool)isServiceAvailable:(char*)service {
    mach_port_t     masterPort;
    kern_return_t   kernResult;
    io_service_t    serviceObject;
    io_iterator_t   iterator;
    CFDictionaryRef classToMatch;
 
    if (IOMasterPort(MACH_PORT_NULL, &masterPort) != KERN_SUCCESS) {
        return NO; // REV/FIX: throw.
    }

    classToMatch = IOServiceMatching("GTDriver");
    if (classToMatch == NULL) {
        NSLog(@"IOServiceMatching returned a NULL dictionary.\n");
        return NO;
    }
    kernResult = IOServiceGetMatchingServices(masterPort,
                                              classToMatch,
                                              &iterator);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"IOServiceGetMatchingServices returned %x\n", kernResult);
        return NO;
    }
    
    serviceObject = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (serviceObject != NULL) {
        IOObjectRelease(serviceObject);
        return YES;
    }
    
    return NO;
}

-(kern_return_t) _connect {
    kern_return_t   kernResult;
    mach_port_t     masterPort;
    io_service_t    serviceObject;
    io_iterator_t   iterator;
    CFDictionaryRef classToMatch;

    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"IOMasterPort returned 0x%x\n", kernResult);
        return kernResult;
    }
    classToMatch = IOServiceMatching("GTDriver");

    if (classToMatch == NULL) {
        NSLog(@"IOServiceMatching returned a NULL dictionary.\n");
        return kernResult;
    }
    kernResult = IOServiceGetMatchingServices(masterPort,
                                              classToMatch,
                                              &iterator);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"IOServiceGetMatchingServices returned %x\n", kernResult);
        return kernResult;
    }

    serviceObject = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (serviceObject != NULL) {
        kernResult = IOServiceOpen(serviceObject, mach_task_self(), 0,
                                   &_userClientPort);

        IOObjectRelease(serviceObject);
        if (kernResult != KERN_SUCCESS) {
            NSLog(@"IOServiceOpen 0x%x\n", kernResult);
            return kernResult;
        }
    }
    
    return kernResult;
}

-(kern_return_t) _disconnect {
    return IOServiceClose(_userClientPort);
}

#pragma mark -

- (id)initWithDriverNamed:(NSString*)driverName {
    self=[super init];
    if(!self) return Nil;
    
    kern_return_t kernResult;

    _driverName = driverName;
 
    kernResult = [self _connect];
    if (kernResult != KERN_SUCCESS) return Nil;
    
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort, kWiFiUserClientOpen, 0, 0);
    if (kernResult != KERN_SUCCESS) {
        [self release];
        return Nil;
    }
    
    [_driverName retain];
    return self;
}

- (unsigned short)linkSpeed {
    return IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWiFiUserClientGetLinkSpeed, 0, 0);
}

- (wirelessState)getConnectionState {
    return IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWiFiUserClientGetConnectionState, 0, 0);
}

- (BOOL)setSSID:(NSString *)ssid {
    return IOConnectMethodScalarIStructureI(_userClientPort,
                                               kWiFiUserClientSetSSID, 0, [ssid cStringLength], [ssid cString]);
}

- (BOOL)setWEPKey:(NSData *)key {
    return IOConnectMethodScalarIStructureI(_userClientPort,
                                               kWiFiUserClientSetWEPKey, 0, [key length], [key bytes]);
}

- (NSDictionary*)getNetworks {
    struct {
        UInt32 size;
        bssItem b[20];
    } x;
    IOByteCount size;
    NSMutableDictionary *dict, *ndict;
    NSString *ssid;
    int i;
    
    size = sizeof(x);
    if (IOConnectMethodScalarIStructureO(_userClientPort,
                                               kWiFiUserClientGetScan, 0, &size, &x) != kIOReturnSuccess) return nil;
    
    dict = [NSMutableDictionary dictionary];
    for(i = 0; i < x.size / sizeof(bssItem); i++) {
        ssid = [NSString stringWithCString:x.b[i].ssid length:x.b[i].ssidLength];
        ndict = [dict objectForKey:ssid];
        if (!ndict) {
            ndict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"Active", [NSNumber numberWithBool:NO], @"WEP", [NSNumber numberWithBool:NO], @"IBSS", [NSMutableArray array], @"Stations", nil];
            [dict setObject:ndict forKey:ssid];
        }
        if (x.b[i].active) [ndict setObject:[NSNumber numberWithBool:YES] forKey:@"Active"];
        [[ndict objectForKey:@"Stations"] addObject:[NSString stringWithFormat:@"%.2x:%.2x:%.2x:%.2x:%.2x:%.2:", (int)x.b[i].address[0], (int)x.b[i].address[1], (int)x.b[i].address[2], (int)x.b[i].address[3], (int)x.b[i].address[4], (int)x.b[i].address[5]]];
        if ((NSSwapLittleShortToHost(x.b[i].cap) & 0x10) == 0x10) [ndict setObject:[NSNumber numberWithBool:YES] forKey:@"WEP"];
        if ((NSSwapLittleShortToHost(x.b[i].cap) & 0x02) == 0x02) [ndict setObject:[NSNumber numberWithBool:YES] forKey:@"IBSS"];
    }
    
    return dict;                           
}

- (BOOL)setMode:(wirelessMode)mode {
    return IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWiFiUserClientSetMode, 1, 0, mode);
}

#pragma mark -

-(void) dealloc {
    kern_return_t kernResult;
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort, kWiFiUserClientClose, 0, 0);
    kernResult = [self _disconnect];
    [_driverName release];
    
    [super dealloc];
}

@end
