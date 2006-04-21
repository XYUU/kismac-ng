/*
        
        File:			WaveDriver.h
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

#import <Cocoa/Cocoa.h>
#import "../Core/80211b.h"

extern char WaveDrivers [][30];

enum WaveDriverType {
    activeDriver,
    passiveDriver,
    notSpecifiedDriver
};

@interface WaveDriver : NSObject {
    NSDictionary *_config;
    int _firstChannel;
    int _currentChannel;
    int _useChannel[14];
    int _autoRepeat;
    int _packets;
    int _lastChannel;
    int _hopFailure;
    int _allowedChannels;
    
    bool _autoAdjustTimer;
    bool _hop;
    bool _etsi;
    bool _fcc;
}

+ (enum WaveDriverType) type;
+ (bool) allowsInjection;
+ (bool) allowsChannelHopping;
+ (bool) allowsMultipleInstances;
+ (NSString*) description;
+ (NSString*) deviceName;

+ (bool) loadBackend;
+ (bool) unloadBackend;

- (enum WaveDriverType) type;
- (bool) allowsInjection;
- (bool) allowsChannelHopping;
- (bool) allowsMultipleInstances;
- (bool) unloadBackend;
- (NSString*) deviceName;

- (NSComparisonResult)compareDrivers:(WaveDriver *)driver;

- (bool)setConfiguration:(NSDictionary*)dict;
- (NSDictionary*)configuration;
- (bool)ETSI;
- (bool)FCC;
- (bool)hopping;
- (bool)autoAdjustTimer;
- (void)hopToNextChannel;

- (unsigned short) getChannel;
- (bool) setChannel:  (unsigned short)newChannel;
- (bool) startCapture:(unsigned short)newChannel;
- (bool) stopCapture;
- (bool) sleepDriver;
- (bool) wakeDriver;

// for active scanning
- (NSArray*) networksInRange;

// for passive scanning
- (WLFrame*) nextFrame;

// for packet injection
- (bool) sendFrame:(UInt8*)f withLength:(int) size atInterval:(int)interval;
- (bool) stopSendingFrames;

//for the cards that support this
- (int) allowedChannels;
@end
