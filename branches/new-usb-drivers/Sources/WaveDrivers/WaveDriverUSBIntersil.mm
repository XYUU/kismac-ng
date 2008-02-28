/*
        
        File:			WaveDriverUSBIntersil.m
        Program:		KisMAC
		Author:			Michael Rossberg
						mick@binaervarianz.de
		Description:	KisMAC is a wireless stumbler for MacOS X.
                
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
#import "WaveDriverUSBIntersil.h"
#import "WaveHelper.h"
#import "../Driver/USBJack/USBJack.h"
#import "../Driver/USBJack/RalinkJack.h"
#import "../Driver/USBJack/RT73Jack.h"
//#import "../Driver/USBJack/ZydasJack.h"

static bool explicitlyLoadedUSBIntersil = NO;

@implementation WaveDriverUSBIntersil

- (id)init {
    int timeoutCount = 0;
    self=[super init];
    if(!self) return Nil;

    _driver = new USBJack;
    //this will only occur once!
    _driver->startMatching();
    NSLog(@"Matching finished\n");
    
    while(!_driver->getDeviceType() && timeoutCount++ < 10)        //wait until the device is found
        usleep(100);
    
    usleep(1000);  //we should really do locking, but since this is temp anyway...
    
    //I don't really like how this works.
    switch(_driver->getDeviceType()){       //cast ourself to the approp type
        case intersil:
            delete(_driver);
            _driver = new IntersilJack;
            break;
        case ralink:
            delete(_driver);
            _driver = new RalinkJack;
            break;
        case rt73:
            delete(_driver);
            _driver = new RT73Jack;
            break;
        case zydas:
            break;
        default:
            NSLog(@"No supported USB Device found!");
            delete(_driver);
            _errors++;
            return Nil;
    }
    
    if(_driver->_init() != kIOReturnSuccess)
        return Nil;
    
	_errors = 0;
	
    return self;
}

#pragma mark -

+ (enum WaveDriverType) type {
    return passiveDriver;
}

+ (bool) allowsInjection {
    return YES;
}

+ (bool) allowsChannelHopping {
    return YES;
}

+ (bool) allowsMultipleInstances {
    return YES;  //may be later
}

+ (NSString*) description {
    return NSLocalizedString(@"USB device, passive mode", "long driver description");
}

+ (NSString*) deviceName {
    return NSLocalizedString(@"USB device", "short driver description");
}

#pragma mark -

+ (bool) loadBackend {
    
    if ([WaveHelper isServiceAvailable:"com_intersil_prism2USB"]) {
        NSRunCriticalAlertPanel(
            NSLocalizedString(@"WARNING! Please unplug your USB device now.", "Warning dialog title"),
            NSLocalizedString(@"Due a bug in Intersils Prism USB driver you must unplug your device now temporarily, otherwise you will not be able to use it any more. KisMAC will prompt you again to put it back in after loading is completed.", "USB driver bug warning."),
            OK, Nil, Nil);
        
		if (![WaveHelper runScript:@"usbprism2_prep.sh"]) return NO;
    
        NSRunInformationalAlertPanel(
            NSLocalizedString(@"Connect your device again!", "dialog title"),
            NSLocalizedString(@"KisMAC completed the unload process. Please plug your device back in before you continue.", "USB driver bug warning."),
            OK, Nil, Nil);
		explicitlyLoadedUSBIntersil = YES;
    } else  if ([WaveHelper isServiceAvailable:"AeroPad"]) {
		if (![WaveHelper runScript:@"usbprism2_prep.sh"]) return NO;
		explicitlyLoadedUSBIntersil = YES;
	}
	
    return YES;
}

+ (bool) unloadBackend {
	if (!explicitlyLoadedUSBIntersil) return YES;
	
    NSLog(@"Restarting the USB drivers");
    return [WaveHelper runScript:@"usbprism2_unprep.sh"];
}

#pragma mark -

- (unsigned short) getChannelUnCached {
    UInt16 channel;
    
    if (_driver->getChannel(&channel)) return channel;
    else return 0;
}

- (bool) setChannel:(unsigned short)newChannel {
    if (((_allowedChannels >> (newChannel - 1)) & 0x0001) == 0) return NO;
    
    return _driver->setChannel(newChannel);
}

- (bool) startCapture:(unsigned short)newChannel {
    if (newChannel == 0) newChannel = _firstChannel;
    return _driver->startCapture(newChannel);
}

- (bool) stopCapture {
    return _driver->stopCapture();
}

- (bool) sleepDriver{
	if (_driver) delete _driver; 
    return YES;
}

- (bool) wakeDriver{
    _driver = new RalinkJack;
    _driver->startMatching();
    return YES;
}

#pragma mark -

- (WLFrame*) nextFrame {
    WLFrame *f;
    
    f = _driver->receiveFrame();
    if (f==NULL) {
		_errors++;
        if (_packets && _driver) {
			if (_errors < 3) {
				NSLog(@"USB receiveFrame failed - attempting to reload driver");
				delete _driver;
				_driver = new RalinkJack;
				_driver->startMatching();
			} else {
				NSLog(@"Excessive errors received - terminating driver");
				delete _driver;
			}
        }
        NSRunCriticalAlertPanel(NSLocalizedString(@"USB Prism2 error", "Error box title"),
                NSLocalizedString(@"USB Prism2 error description", "LONG Error description"),
                //@"A driver error occured with your USB device, make sure it is properly connected. Scanning will "
                //"be canceled. Errors may have be printed to console.log."
                OK, Nil, Nil);

    } else {
        _packets++;
		_errors=0;
	}
    
    return f;
}

#pragma mark -

- (void)doInjection:(NSData*)data {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    while(_transmitting) {
        _driver->sendFrame((UInt8*)[data bytes]);
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:_interval]];
    }
    [data release];
    
    [pool release];
}

-(bool) sendFrame:(UInt8*)f withLength:(int) size atInterval:(int)interval {
    NSData *data;
    
    if (interval) {
        [self stopSendingFrames];
        data = [[NSData dataWithBytes:f length:size] retain];
        _transmitting = YES;
        _interval = (float)interval / 1000.0;
        [NSThread detachNewThreadSelector:@selector(doInjection:) toTarget:self withObject:data];
    } else {
        _driver->sendFrame(f);
    }
    
    return YES;
}

-(bool) stopSendingFrames {    
    _transmitting = NO;
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:_interval]];
    return YES;
}

#pragma mark -

- (int) allowedChannels {
    UInt16 channels;
    
    if (_allowedChannels) return _allowedChannels;
    
    if (_driver->getAllowedChannels(&channels)) {
        _allowedChannels = channels;
        return channels;
    } else return 0xFFFF;
}

#pragma mark -

-(void) dealloc {
    [self stopSendingFrames];
    
    delete _driver;
    _driver = NULL;
    
    [super dealloc];
}

@end
