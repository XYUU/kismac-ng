/*
        
        File:			WaveScanner.h
        Program:		KisMAC
	Author:			Michael Ro§berg
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

#import <AppKit/AppKit.h>
#import <pcap.h>

#import "WaveNet.h"
#import "WavePacket.h"
#import "WaveHelper.h"
#import "WaveContainer.h"

struct __authFrame {
    WLFrame     hdr;
    UInt16	wi_algo;
    UInt16	wi_seq;
    UInt16	wi_status;
}__attribute__ ((packed));

struct __beaconFrame {
    WLFrame     hdr;
    UInt64	wi_timestamp;
    UInt16	wi_interval;
    UInt16	wi_capinfo;
    UInt8       wi_tag_ssid;
    UInt8       wi_ssid_len;
    UInt32      wi_ssid; //normally variable
    UInt8       wi_tag_rates;
    UInt8       wi_rates_len;
    UInt32      wi_rates;
    UInt8       wi_tag_channel;
    UInt8       wi_channel_len;
    UInt8       wi_channel;
}__attribute__ ((packed));

@interface WaveScanner : NSObject {    
    NSTimer* _scanTimer;		//timer for refreshing the tables
    NSTimer* _hopTimer;                 //channel hopper

    NSString* _geigerSound;             //sound file for the geiger counter

    int _packets;			//packet count
    int aGeigerInt;
    int aBytes;				//bytes since last refresh (for graph)
    bool _soundBusy;			//are we clicking?
    
    NSArray *_drivers;
    
    bool _authenticationFlooding;
    struct __authFrame _authFrame;
    bool _beaconFlooding;
    struct __beaconFrame _beaconFrame;
    
    int graphLength;
    NSTimeInterval scanInterval;	//refresh interval
    
    UInt8 _MACs[18];
    bool aTODS;
    int  aInjReplies;
    int  aPacketType;
    bool aScanRange;
    bool aScanning;
    bool _injecting;
    bool aScanThreadUp;
    double aFreq;
    int  _driver;
    
    unsigned char aFrameBuf[2364];	//for reading in pcaps (still messy)
    WLFrame* aWF;
    pcap_t*  aPCapT;

    ImportController *_im;

    IBOutlet id aController;
    IBOutlet WaveContainer* _container;
}

//funtions for loading/saving
- (bool)saveToFile:(NSString*)fileName;
- (bool)exportNSToFile:(NSString*)fileName;
- (bool)exportMacStumblerToFile:(NSString*)fileName;
- (bool)loadFromFile:(NSString*)fileName;
- (bool)importFromFile:(NSString*)fileName;
- (bool)importFromNetstumbler:(NSString*)fileName;
- (NSString*)webServiceData;

- (void)readPCAPDump:(NSString*)dumpFile;
- (WLFrame*) nextFrame:(bool*)corrupted;	//internal usage only

//for communications with ScanController which does all the graphic stuff
- (int) graphLength;

//scanning properties
- (void) setFrequency:(double)newFreq;
- (bool) startScanning;
- (bool) stopScanning;
- (void) setGeigerInterval:(int)newGeigerInt sound:(NSString*) newSound;
- (void) clearAllNetworks;
- (void) clearNetwork:(WaveNet*)net;
- (NSTimeInterval) scanInterval;

//active attacks
- (NSString*) tryToInject:(WaveNet*)net;
- (bool) authFloodNetwork:(WaveNet*)net;
- (bool) deauthenticateNetwork:(WaveNet*)net atInterval:(int)interval;
- (bool) beaconFlood;
- (bool) stopSendingFrames;

- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)aBool;
@end
