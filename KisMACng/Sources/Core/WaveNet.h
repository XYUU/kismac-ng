/*
        
        File:			WaveNet.h
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

#import <Cocoa/Cocoa.h>
#import "WavePacket.h"
#import "ImportController.h"
#import "Apple80211.h"

enum {
    trafficData,
    packetData,
    signalData
};

struct graphStruct {
    int trafficData[MAX_YIELD_SIZE + 1];
    int packetData[MAX_YIELD_SIZE + 1];
    int signalData[MAX_YIELD_SIZE + 1];
};

@class NetView;
@class WaveWeakContainer;

@interface WaveNet : NSObject {
    int aNetID;			//network ID
    int aMaxSignal;		//biggest signal ever
    int aCurSignal;		//current signal
    int aChannel;		//last channel
    int _originalChannel;       //channel which is brodacsted by AP
    networkType _type;          //0=unknown, 1=ad-hoc, 2=managed, 3=tunnel 4=probe 5=lucent tunnel
    int _packets;		//# of packets
    int _packetsPerChannel[16];	//how many packets on each channel
    int _dataPackets;		//# of data packets
    double aBytes;		//bytes, float because of size
    int graphLength;
    struct graphStruct graphData;
    encryptionType _isWep;      //0=unknown, 1=disabled, 2=enabled 3=40-bit 4-WPA
    UInt8 aIV[3]; 		//last iv
    UInt8 aRawID[6];		//our id
    UInt8 aRawBSSID[6];		//our bssid
    UInt8 aPoint1[6];		//tunnel partner 1
    UInt8 aPoint2[6];		//tunnel partner 2
    bool _gotData;
    bool _firstPacket;
    bool _liveCaptured;
    
    NSRecursiveLock *_dataLock;
    
    NetView*  _netView;
    NSString* aLat;
    NSString* aLong;
    NSString* aElev;
    NSString *_crackErrorString;

    NSString* _SSID;
    NSString* aBSSID;
    NSString* aVendor;
    NSString* _password;
    NSString* aComment;
    NSString* aID;
    NSDate* aDate;		//current date
    NSDate* aFirstDate;
    NSMutableArray* aPacketsLog;    //array with a couple of packets to calculate checksum
    NSMutableArray* _ARPLog;        //array with a couple of packets to do reinjection attack
    NSMutableArray* _ACKLog;        //array with a couple of packets to do reinjection attack
    NSMutableDictionary* aClients;
    NSMutableArray* aClientKeys;
    NSMutableDictionary* _coordinates;
    WaveWeakContainer *_ivData[4];       //one for each key id
    
    id _cracker;		//cracker for this net
 
    NSColor* _graphColor;	// display color in TrafficView
    int recentTraffic;
    int recentPackets;
    int recentSignal;
    int curPackets;		// for setting graphData
    int curTraffic;		// for setting graphData
    int curTrafficData;		// for setting graphData
    int curPacketData;		// for setting graphData
    int curSignalData;		// for setting graphData
    int _avgTime;               // how many seconds are take for average?

    ImportController *_im;
}


- (void)updateSettings:(NSNotification*)note;

- (bool)noteFinishedSweep:(int)num;
- (NSColor*)graphColor;
- (void)setGraphColor:(NSColor*)newColor;
- (NSComparisonResult)compareSignalTo:(id)net;
- (NSComparisonResult)comparePacketsTo:(id)net;
- (NSComparisonResult)compareTrafficTo:(id)net;
- (NSComparisonResult)compareRecentTrafficTo:(id)aNet;

- (id)initWithID:(int)netID;
- (id)initWithNetstumbler:(const char*)buf andDate:(NSString*)date;
- (void)mergeWithNet:(WaveNet*)net;

- (struct graphStruct)graphData;
- (NSDictionary*)getClients;
- (NSArray*)getClientKeys;
- (void)updatePassword;

- (encryptionType)wep;
- (NSString *)ID;
- (NSString *)BSSID;
- (NSString *)SSID;
- (NSString *)rawSSID;
- (NSString *)date;
- (NSDate*)lastSeenDate;
- (NSString *)firstDate;
- (NSDate *)firstSeenDate;
- (NSString*)data;
- (NSString*)getVendor;
- (NSArray*)weakPacketsLog;             //a couple of encrypted packets
- (NSMutableArray*)arpPacketsLog;	//a couple of reinject packets
- (NSMutableArray*)ackPacketsLog;	//a couple of reinject packets
- (NSString*)key;
- (NSString*)lastIV;
- (NSString*)comment;
- (void)setComment:(NSString*)comment;
- (NSDictionary*)coordinates;
- (WaveWeakContainer **)ivData;
- (BOOL)passwordAvailable;

- (NSString *)latitude;
- (NSString *)longitude;
- (NSString *)elevation;

- (float)dataCount;
- (int)curTraffic;
- (int)curPackets;
- (int)curSignal;
- (int)maxSignal;
- (int)avgSignal;
- (int)channel;
- (int)originalChannel;
- (networkType)type;
- (int)packets;
- (int)uniqueIVs;
- (int)dataPackets;
- (int*)packetsPerChannel;
- (void)setNetID:(int)netID;
- (int)netID;
- (UInt8*)rawBSSID;
- (UInt8*)rawID;
- (bool)liveCaptured;

- (bool)joinNetwork;

- (void)parsePacket:(WavePacket*) w withSound:(bool)sound;
- (void)parseAppleAPIData:(WirelessNetworkInfo*)info;

- (void)sortByColumn:(NSString*)ident order:(bool)ascend;

- (BOOL)crackWPAWithImportController:(ImportController*)im;
- (BOOL)crackLEAPWithImportController:(ImportController*)im;
- (void)reinjectWithImportController:(ImportController*)im andScanner:(id)scanner;

- (NSString*)crackError;

@end
