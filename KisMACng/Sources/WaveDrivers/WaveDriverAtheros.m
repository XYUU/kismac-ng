/*
        
        File:			WaveDriverAtheros.m
        Program:		KisMAC
	Author:			Michael Rossberg
				mick@binaervarianz.de
	Description:		KisMAC is a wireless stumbler for MacOS X.
                
        This file is part of KisMAC.

    KisMAC is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    KisMAC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with KisMAC; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <IOKit/IOKitLib.h>
#import <IOKit/IODataQueueClient.h>
#import "WaveDriverAtheros.h"
#import "ImportController.h"
#import "WaveHelper.h"

#define driverName "AtherosWIFIController"

static bool explicitlyLoadedAtheros = NO;

typedef enum WLUCMethods {
    kWLUserClientOpen,                      // kIOUCScalarIScalarO, 0, 0
    kWLUserClientClose,                     // kIOUCScalarIScalarO, 0, 0
    kWLUserClientEnable,                    // kIOUCScalarIScalarO, 0, 0
    kWLUserClientDisable,                   // kIOUCScalarIScalarO, 0, 0
    kWLUserClientGetFrequency,              // kIOUCScalarIScalarO, 0, 1
    kWLUserClientSetFrequency,              // kIOUCScalarIScalarO, 1, 0
    kWLUserClientGetOpMode,                 // kIOUCScalarIScalarO, 0, 1
    kWLUserClientSetOpMode,                 // kIOUCScalarIScalarO, 1, 0
    kWLUserClientSupportedOpModes,          // kIOUCScalarIScalarO, 0, 1
    kWLUserClientLastMethod,
} WLUCMethod;

enum _operationMode {
    _operationModeStation   = 0x01,
    _operationModeIBSS      = 0x02,
    _operationModeHostAP    = 0x04,
    _operationModeMonitor   = 0x08,
    _operationModeInvalid   = 0x00,
};

@implementation WaveDriverAtheros

+ (enum WaveDriverType) type {
    return passiveDriver;
}

+ (bool) allowsInjection {
    return NO;
}

+ (bool) allowsChannelHopping {
    return YES;
}

+ (NSString*) description {
    return NSLocalizedString(@"Atheros based card, passive mode", "long driver description");
}

+ (NSString*) deviceName {
    return NSLocalizedString(@"Atheros based Card", "short driver description");
}

#pragma mark -

// return 0 for success, 1 for error, 2 for self handled error
+ (int) initBackend {
    int x;
    
    if ([WaveHelper isServiceAvailable:driverName]) return 0;
    explicitlyLoadedAtheros = YES;
    
    if (![WaveHelper runScript:@"atheros_load.sh"]) return 2;

    for(x = 0; x < 70; x++) {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        
        if ([WaveHelper isServiceAvailable:driverName]) return 0;
    }
    
    return 1;
}

+ (bool) loadBackend {
    ImportController *importController;
    int result;
    int x;
        
    do {
        importController = [[ImportController alloc] initWithWindowNibName:@"Import"];
        [importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", "for Backend loading"), [self description]]];
    
        [NSApp beginSheet:[importController window] modalForWindow:[WaveHelper mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
        
        result = [self initBackend];
    
        [NSApp endSheet: [importController window]];        
        [[importController window] close];
        [importController stopAnimation];
        [importController release];
        importController=Nil;
            
        if (result == 1) {	//see if we actually have the driver accessed
            x = [WaveHelper showCouldNotInstaniciateDialog:[self description]];
        }
    } while (result==1 && x==1);

    return (result==0);
}

+ (bool) unloadBackend {
    if (!explicitlyLoadedAtheros) return YES;
    return [WaveHelper runScript:@"atheros_unload.sh"];
}

#pragma mark -

-(kern_return_t) _connect
{
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
    classToMatch = IOServiceMatching(_driverName);

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

    kernResult = IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWLUserClientSetOpMode, 1, 0, _operationModeMonitor);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"setOpMode: IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
        return NO;
    }

    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    
    kernResult = IOConnectMapMemory(_userClientPort,
                                    _userClientMap,
                                    mach_task_self(),
                                    (vm_address_t*)&_packetQueue,
                                    &_packetQueueSize,
                                    kIOMapAnywhere);
    if (kernResult != kIOReturnSuccess) {
        NSLog(@"IOConnectMapMemory 0x%x\n", kernResult);
        return kernResult;
    }

    _packetQueuePort = IODataQueueAllocateNotificationPort();
    kernResult = IOConnectSetNotificationPort(_userClientPort,
                                              _userClientNotify,
                                              _packetQueuePort,
                                              0);
    
    if (kernResult != kIOReturnSuccess) {
        NSLog(@"IOConnectSetNotificationPort 0x%x\n", kernResult);
        return kernResult;
    }

    return kernResult;
}

-(kern_return_t) _disconnect {
    return IOServiceClose(_userClientPort);
}

#pragma mark -

- (id)init {
    self=[super init];
    if(!self) return Nil;

    _userClientNotify = 0xdeadbeef;
    _userClientMap = 0xdeadbeef;
    _driverName = driverName;
    
    kern_return_t kernResult;

    kernResult = [self _connect];
    if (kernResult != KERN_SUCCESS) return Nil;
    
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort, kWLUserClientOpen, 0, 0);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"open: IOConnectMethodScalarIScalarO: %x (driver not loaded?)\n", kernResult);
        [self release];
        return Nil;
    }
    
    return self;
}

#pragma mark -

- (unsigned short) getChannelUnCached {
    UInt32 channel = 0;
    kern_return_t kernResult;

    if (![self allowsChannelHopping]) return 0;
    
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWLUserClientGetFrequency, 0, 1, &channel);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"getChannel: IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
        return 0;
    }
    
    return [WaveHelper freq2chan:channel];
}

- (bool) setChannel:(unsigned short)newChannel {
    kern_return_t kernResult;
 
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort,
                                               kWLUserClientSetFrequency, 1, 0, [WaveHelper chan2freq: newChannel]);
    if (kernResult != KERN_SUCCESS) {
        //NSLog(@"setChannel: IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
        return NO;
    }
    
    return YES;
}

- (bool) startCapture:(unsigned short)newChannel {
    kern_return_t kernResult;

    [self setChannel: newChannel];
     
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort, kWLUserClientEnable, 0, 0);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"startCapture: IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
        return NO;
    }
    
    return YES;
}

-(bool) stopCapture {
    kern_return_t kernResult;

    kernResult = IOConnectMethodScalarIScalarO(_userClientPort, kWLUserClientDisable, 0, 0);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
        return NO;
    }

    while (IODataQueueDataAvailable(_packetQueue)) IODataQueueDequeue(_packetQueue, NULL, 0);

    return YES;
}

#pragma mark -

- (WLFrame*) nextFrame {
    static UInt8  frame[2364];
    UInt8  tempframe[2364];
    UInt32 frameSize = 2364;
    kern_return_t kernResult;
    UInt16 dataLen;
    WLFrame *f;
    
    
    do {
        while (!IODataQueueDataAvailable(_packetQueue)) {
            kernResult = IODataQueueWaitForAvailableData(_packetQueue,
                                                         _packetQueuePort);
            if (kernResult != KERN_SUCCESS) {
                NSLog(@"nextFrame: IODataQueueWaitForAvailableData: 0x%x\n", kernResult);
                return NULL;
            }
        }

        kernResult = IODataQueueDequeue(_packetQueue, tempframe, &frameSize);
    } while (kernResult != KERN_SUCCESS);
    
    /*{
        NSLog(@"nextFrame: IODataQueueDequeue: 0x%x\n", kernResult);
        return NULL;
    }
    else {*/
    
        f = (WLFrame*)tempframe;
        
        memcpy(frame, tempframe, 38);
        dataLen = (f->reserved1 > 28) ? f->reserved1 - 28 : 0;
        
        memcpy(frame + sizeof(WLFrame), &f->address4[0], dataLen);
        f = (WLFrame*)frame;
        f->dataLen = dataLen;
        f->length = dataLen ;
        _packets++;
        return (WLFrame*)frame;
    //}
}


#pragma mark -

-(bool) sendFrame:(UInt8*)f withLength:(int) size atInterval:(int)interval {
    return NO;
}

-(bool) stopSendingFrames {    
    return NO;
}

#pragma mark -

-(void) dealloc {
    kern_return_t kernResult;
    kernResult = IOConnectMethodScalarIScalarO(_userClientPort,kWLUserClientClose,0, 0);
    if (kernResult != KERN_SUCCESS) NSLog(@"close: IOConnectMethodScalarIScalarO: 0x%x\n", kernResult);
    kernResult = [self _disconnect];
    [super dealloc];
}

@end
