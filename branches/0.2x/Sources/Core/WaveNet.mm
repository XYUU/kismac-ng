/*
        
        File:			WaveNet.mm
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

#import <AppKit/NSSound.h>
#import <BIGeneric/BIGeneric.h>
#import "WaveNet.h"
#import "WaveClient.h"
#import "WaveHelper.h"
#import "80211b.h"
#import "WaveNetWPACrack.h"
#import "WaveNetLEAPCrack.h"
#import "WaveNetWPACrackAltivec.h"
#import "WaveScanner.h"
#import "KisMACNotifications.h"
#import "GPSController.h"
#import "NetView.h"
#import "WaveWeakContainer.h"

#define AMOD(x, y) ((x) % (y) < 0 ? ((x) % (y)) + (y) : (x) % (y))
#define N 256

#define min(a, b)	(a) < (b) ? a : b

struct graphStruct zeroGraphData;

struct signalCoords {
	double x, y;
	int strength;
} __attribute__((packed));
		
int lengthSort(id string1, id string2, void *context)
{
    int v1 = [(NSString*)string1 length];
    int v2 = [(NSString*)string2 length];
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

@implementation WaveNet

-(id)initWithID:(int)netID {
    waypoint cp;
    GPSController *gpsc;

    self = [super init];
    
    if (!self) return nil;
    
    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];
	// we should only create a _netView for this network if we have the information to see it
	// check with GPSController if we have a location or not!
	gpsc = [WaveHelper gpsController];
	cp = [gpsc currentPoint];    
	if (cp._lat != 100) _netView = [[NetView alloc] initWithNetwork:self];
	
    _ID = nil;
	graphData = &zeroGraphData;
	
    _packetsLog=[[NSMutableArray arrayWithCapacity:20] retain];
    _ARPLog=[[NSMutableArray arrayWithCapacity:20] retain];
    _ACKLog=[[NSMutableArray arrayWithCapacity:20] retain];
    aClients=[[NSMutableDictionary dictionary] retain];
    aClientKeys=[[NSMutableArray array] retain];
    aComment=[[NSString stringWithString:@""] retain];
    aLat = [[NSString stringWithString:@""] retain];
    aLong = [[NSString stringWithString:@""] retain];
    aElev = [[NSString stringWithString:@""] retain];
    _coordinates = [[NSMutableDictionary dictionary] retain];
    _netID=netID;

    _gotData = NO;
    recentTraffic = 0;
    curTraffic = 0;
    curPackets = 0;
    _curSignal = 0;
    _channel = 0;
    _primaryChannel = 0;
    curTrafficData = 0;
    curPacketData = 0;
    _rateCount = 0;
	
    _SSID = Nil;
    _firstPacket = YES;
    _liveCaptured = NO;
    aFirstDate = [[NSDate date] retain];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    waypoint wp;
    int bssid[6];
    NSData *data;
        
    if (![coder allowsKeyedCoding]) {
        NSLog(@"Cannot decode this way");
        return nil;
    }

    if ([coder decodeObjectForKey:@"aFirstDate"] == Nil) {
        NSLog(@"Invalid net, dropping!");
        return Nil;
    }
    
    self = [self init];
    if (!self) return nil;

    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];

	graphData = &zeroGraphData;
    _channel = [coder decodeIntForKey:@"aChannel"];
    _primaryChannel = [coder decodeIntForKey:@"originalChannel"];
    _netID=[coder decodeIntForKey:@"aNetID"];
    _packets=[coder decodeIntForKey:@"aPackets"];
    _maxSignal=[coder decodeIntForKey:@"aMaxSignal"];
    _curSignal=[coder decodeIntForKey:@"aCurSignal"];
    _type=(networkType)[coder decodeIntForKey:@"aType"];
    _isWep = (encryptionType)[coder decodeIntForKey:@"aIsWep"];
    _dataPackets=[coder decodeIntForKey:@"aDataPackets"];
    _liveCaptured=[coder decodeBoolForKey:@"_liveCaptured"];;
    
    for(int x=0; x<14; x++)
        _packetsPerChannel[x]=[coder decodeIntForKey:[NSString stringWithFormat:@"_packetsPerChannel%i",x]];
    
    _bytes = [coder decodeDoubleForKey:@"aBytes"];
    wp._lat = [coder decodeDoubleForKey:@"a_Lat"];
    wp._long = [coder decodeDoubleForKey:@"a_Long"];
    wp._elevation = [coder decodeDoubleForKey:@"a_Elev"];
    
    aLat = [[coder decodeObjectForKey:@"aLat"] retain];
    aLong = [[coder decodeObjectForKey:@"aLong"] retain];
    aElev = [[coder decodeObjectForKey:@"aElev"] retain];
    
    _ID=[[coder decodeObjectForKey:@"aID"] retain];
    if (_ID!=Nil && sscanf([_ID cString], "%2X%2X%2X%2X%2X%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) {
        NSLog(@"Error could not decode ID %@!", _ID);
    }
    
    for (int x=0; x<6; x++)
        _rawID[x] = bssid[x];
    
    _SSID=[[coder decodeObjectForKey:@"aSSID"] retain];
    _BSSID=[[coder decodeObjectForKey:@"aBSSID"] retain];
    if (![_BSSID isEqualToString:@"<no bssid>"]) {
        if (_BSSID!=Nil && sscanf([_BSSID cString], "%2X:%2X:%2X:%2X:%2X:%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) 
            NSLog(@"Error could not decode BSSID %@!", _BSSID);
        for (int x=0; x<6; x++)
            _rawBSSID[x] = bssid[x];
    } else {
         for (int x=0; x<6; x++)
            _rawBSSID[x] = bssid[0];
    }
    _date=[[coder decodeObjectForKey:@"aDate"] retain];
    aFirstDate=[[coder decodeObjectForKey:@"aFirstDate"] retain];
    
    data = [coder decodeObjectForKey:@"ivData0"];
    if (data) _ivData[0] = [[WaveWeakContainer alloc] initWithData:data];
    data = [coder decodeObjectForKey:@"ivData1"];
    if (data) _ivData[1] = [[WaveWeakContainer alloc] initWithData:data];
    data = [coder decodeObjectForKey:@"ivData2"];
    if (data) _ivData[2] = [[WaveWeakContainer alloc] initWithData:data];
    data = [coder decodeObjectForKey:@"ivData3"];
    if (data) _ivData[3] = [[WaveWeakContainer alloc] initWithData:data];
    
    //_packetsLog=[[coder decodeObjectForKey:@"aPacketsLog"] retain];
    //_ARPLog=[[coder decodeObjectForKey:@"aARPLog"] retain]; cannot be used because it is now data
    //_ACKLog=[[coder decodeObjectForKey:@"aACKLog"] retain];
    _password=[[coder decodeObjectForKey:@"aPassword"] retain];
    aComment=[[coder decodeObjectForKey:@"aComment"] retain];
    _coordinates=[[coder decodeObjectForKey:@"_coordinates"] retain];
    
    aClients=[[coder decodeObjectForKey:@"aClients"] retain];
    aClientKeys=[[coder decodeObjectForKey:@"aClientKeys"] retain];
    
    if (!_packetsLog) _packetsLog=[[NSMutableArray arrayWithCapacity:20] retain];
    if (!_ARPLog) _ARPLog=[[NSMutableArray arrayWithCapacity:20] retain];
    if (!_ACKLog) _ACKLog=[[NSMutableArray arrayWithCapacity:20] retain];
    if (!aClients) aClients=[[NSMutableDictionary dictionary] retain];
    if (!aClientKeys) aClientKeys=[[NSMutableArray array] retain];
    if (!aComment) aComment=[[NSString stringWithString:@""] retain];
    if (!aLat) aLat = [[NSString stringWithString:@""] retain];
    if (!aLong) aLong = [[NSString stringWithString:@""] retain];
    if (!aElev) aElev = [[NSString stringWithString:@""] retain];
    if (!_coordinates) _coordinates = [[NSMutableDictionary dictionary] retain];
    
    if (_primaryChannel == 0) _primaryChannel = _channel;
    _gotData = NO;
    
    if (wp._long != 100) {
		_netView = [[NetView alloc] initWithNetwork:self];
		[_netView setWep:_isWep];
		[_netView setName:_SSID];
		[_netView setCoord:wp];
	}
	
    _firstPacket = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (id)initWithNetstumbler:(const char*)buf andDate:(NSString*)date {
    waypoint wp;
    char ns_dir, ew_dir;
    float ns_coord, ew_coord;
    char ssid[255], temp_bss[8];
    unsigned int hour, min, sec, bssid[6], channelbits = 0, flags = 0;
    int interval = 0;
    
    self = [super init];
    
    if (!self) return nil;
    
    if(sscanf(buf, "%c %f %c %f (%*c%254[^)]) %7s "
    "( %2x:%2x:%2x:%2x:%2x:%2x ) %d:%d:%d (GMT) [ %d %*d %*d ] "
    "# ( %*[^)]) %x %x %d",
    &ns_dir, &ns_coord, &ew_dir, &ew_coord, ssid, temp_bss,
    &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5],
    &hour, &min, &sec,
    &_maxSignal,
    &flags, &channelbits, &interval) < 9) {
        NSLog(@"line in backup file is corrupt or not compatible");
        [self release];
        return Nil;
    }

    if(ssid[strlen(ssid) - 1] == ' ') ssid[strlen(ssid) - 1] = '\0';

    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];
    
	graphData = &zeroGraphData;
	
    if (strcmp(temp_bss, "IBSS") == 0)          _type = networkTypeAdHoc;
    else if (strcmp(temp_bss, "ad-hoc") == 0)   _type = networkTypeAdHoc;
    else if (strcmp(temp_bss, "BSS") == 0)      _type = networkTypeManaged;
    else if (strcmp(temp_bss, "TUNNEL") == 0)   _type = networkTypeTunnel;
    else if (strcmp(temp_bss, "PROBE") == 0)    _type = networkTypeProbe;
    else if (strcmp(temp_bss, "LTUNNEL") == 0)  _type = networkTypeLucentTunnel;
    else _type = networkTypeUnknown;

    _isWep = (flags & 0x0010) ? encryptionTypeWEP : encryptionTypeNone;

    _date = [[NSDate dateWithString:[NSString stringWithFormat:@"%@ %.2d:%.2d:%.2d +0000", date, hour, min, sec]] retain];
    aFirstDate = [_date retain];
    
    aLat  = [[NSString stringWithFormat:@"%f%c", ns_coord, ns_dir] retain];
    aLong = [[NSString stringWithFormat:@"%f%c", ew_coord, ew_dir] retain];
    _SSID = [[NSString stringWithCString: ssid] retain];

    _ID = [[NSString stringWithFormat:@"%2X%2X%2X%2X%2X%2X", bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]] retain];
    _BSSID = [[NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]] retain];
    for (int x=0; x<6; x++)
        _rawID[x] = bssid[x];
    
    wp._lat  = ns_coord * (ns_dir == 'N' ? 1.0 : -1.0);
    wp._long = ew_coord * (ew_dir == 'E' ? 1.0 : -1.0);
    wp._elevation = 0;

	if (!(wp._long == 100 || (wp._lat == 0 && wp._long == 0))) {
		_netView = [[NetView alloc] initWithNetwork:self];
		[_netView setWep:_isWep];
		[_netView setName:_SSID];
		[_netView setCoord:wp];
	}
		
    _packetsLog = [[NSMutableArray arrayWithCapacity:20] retain];
    _ARPLog  = [[NSMutableArray arrayWithCapacity:20] retain];
    _ACKLog  = [[NSMutableArray arrayWithCapacity:20] retain];
    aClients = [[NSMutableDictionary dictionary] retain];
    aClientKeys = [[NSMutableArray array] retain];
    aComment = [[NSString stringWithString:@""] retain];
    aElev = [[NSString stringWithString:@""] retain];
    _coordinates = [[NSMutableDictionary dictionary] retain];
    _netID = 0;

    _gotData = NO;
    _liveCaptured = NO;
    recentTraffic = 0;
    curTraffic = 0;
    curPackets = 0;
    _curSignal = 0;
    curTrafficData = 0;
    curPacketData = 0;
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (id)initWithDataDictionary:(NSDictionary*)dict {
    waypoint wp;
    int bssid[6];
    NSData *data;
    NSMutableDictionary *clients;
	
	NSParameterAssert(dict);
	
	if ([dict objectForKey:@"ID"] == Nil) {
        NSLog(@"Invalid net, dropping!");
        return Nil;
    }
    
    self = [self init];
    if (!self) return nil;

    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];
	
	graphData = &zeroGraphData;
	
    _channel = [[dict objectForKey:@"channel"] intValue];
    _primaryChannel = [[dict objectForKey:@"originalChannel"] intValue];
    _netID = [[dict objectForKey:@"netID"] intValue];
    _packets = [[dict objectForKey:@"packets"] intValue];
    _maxSignal = [[dict objectForKey:@"maxSignal"] intValue];
    _curSignal = [[dict objectForKey:@"curSignal"] intValue];
    _type = (networkType)[[dict objectForKey:@"type"] intValue];
    _isWep = (encryptionType)[[dict objectForKey:@"encryption"] intValue];
    _dataPackets = [[dict objectForKey:@"dataPackets"] intValue];
    _liveCaptured = [[dict objectForKey:@"liveCaptured"] boolValue];
    
	for(int x=0; x<14; x++)
        _packetsPerChannel[x] = [[[dict objectForKey:@"packetsPerChannel"] objectForKey:[NSString stringWithFormat:@"%.2i",x]] intValue];
    
    _bytes = [[dict objectForKey:@"bytes"] doubleValue];
    wp._lat = [[dict objectForKey:@"lat"] doubleValue];
    wp._long = [[dict objectForKey:@"long"] doubleValue];
    wp._elevation = [[dict objectForKey:@"elev"] doubleValue];
    
    _ID=[[dict objectForKey:@"ID"] retain];
    if (_ID!=Nil && sscanf([_ID cString], "%2X%2X%2X%2X%2X%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) {
        NSLog(@"Error could not decode ID %@!", _ID);
    }
    
    for (int x=0; x<6; x++)
        _rawID[x] = bssid[x];
    
    _SSID  = [[dict objectForKey:@"SSID"] retain];
    _SSIDs = [[dict objectForKey:@"SSIDs"] retain];
    _BSSID=[[dict objectForKey:@"BSSID"] retain];
    if (![_BSSID isEqualToString:@"<no bssid>"]) {
        if (_BSSID!=Nil && sscanf([_BSSID cString], "%2X:%2X:%2X:%2X:%2X:%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) 
            NSLog(@"Error could not decode BSSID %@!", _BSSID);
        for (int x=0; x<6; x++)
            _rawBSSID[x] = bssid[x];
    } else {
         for (int x=0; x<6; x++)
            _rawBSSID[x] = bssid[0];
    }
    _date=[[dict objectForKey:@"date"] retain];
    aFirstDate = [[dict objectForKey:@"firstDate"] retain];
    
	data = [dict objectForKey:@"rates"];
	_rateCount = min([data length], MAX_RATE_COUNT);
	[data getBytes:_rates length:_rateCount];
	
    data = [dict objectForKey:@"ivData0"];
    if (data) _ivData[0] = [[WaveWeakContainer alloc] initWithData:data];
    data = [dict objectForKey:@"ivData1"];
    if (data) _ivData[1] = [[WaveWeakContainer alloc] initWithData:data];
    data = [dict objectForKey:@"ivData2"];
    if (data) _ivData[2] = [[WaveWeakContainer alloc] initWithData:data];
    data = [dict objectForKey:@"ivData3"];
    if (data) _ivData[3] = [[WaveWeakContainer alloc] initWithData:data];
    
    _packetsLog = [[dict objectForKey:@"packetsLog"] mutableCopy];
    if (!_packetsLog) _packetsLog = [[NSMutableArray arrayWithCapacity:20] retain];
    _ARPLog = [[dict objectForKey:@"ARPLog"] mutableCopy];
    if (!_ARPLog) _ARPLog = [[NSMutableArray arrayWithCapacity:100] retain];
    _ACKLog = [[dict objectForKey:@"ACKLog"] mutableCopy];
    if (!_ACKLog) _ACKLog = [[NSMutableArray arrayWithCapacity:20] retain];
    aClientKeys = [[dict objectForKey:@"clientKeys"] mutableCopy];
    clients = [dict objectForKey:@"clients"];
	if (!clients) aClients = [[NSMutableDictionary dictionary] retain];
    else {
		NSString *c;
		aClients = [[NSMutableDictionary dictionaryWithCapacity:[clients count]] retain];
		NSEnumerator *e = [clients keyEnumerator];
		
		while ((c = [e nextObject])) {
			[aClients setObject:[[[WaveClient alloc] initWithDataDictionary:[clients objectForKey:c]] autorelease] forKey:c];
		}
		aClientKeys = [[aClients allKeys] mutableCopy];
	}
    
	_password = [[dict objectForKey:@"password"] retain];
    
	aComment = [[dict objectForKey:@"comment"] retain];
    if (!aComment) aComment = [[NSString stringWithString:@""] retain];
    aLat = [[dict objectForKey:@"latString"] retain];
    if (!aLat) aLat = [[NSString stringWithString:@""] retain];
    aLong = [[dict objectForKey:@"longString"] retain];
    if (!aLong) aLong = [[NSString stringWithString:@""] retain];
    aElev = [[dict objectForKey:@"elevString"] retain];
    if (!aElev) aElev = [[NSString stringWithString:@""] retain];

	_coordinates = [[dict objectForKey:@"coordinates"] retain];
    if (!_coordinates) _coordinates = [[NSMutableDictionary dictionary] retain];
    else {
		NSData *d;
		BIValuePair *vp;
		
		d = (NSData*)_coordinates;
		_coordinates = [[NSMutableDictionary dictionary] retain];
		const struct signalCoords *pL;
		
		if ([d length] % sizeof(struct signalCoords) == 0) {
			pL = (const struct signalCoords *)[d bytes];
		
			for (unsigned int i = 0; i < ([d length] / sizeof(struct signalCoords)); i++) {
				vp = [BIValuePair new];
				[vp setPairX:pL->x Y:pL->y];
				[_coordinates setObject:[NSNumber numberWithInt:pL->strength] forKey:[vp autorelease]];
				pL++;
			}
		}
	}

    if (_primaryChannel == 0) _primaryChannel = _channel;
    _gotData = NO;
    
	if(wp._long != 100) {
		_netView = [[NetView alloc] initWithNetwork:self];
		[_netView setWep:_isWep];
		[_netView setName:_SSID];
		[_netView setCoord:wp];
	}
	
    _firstPacket = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (NSDictionary*)dataDictionary {
    waypoint wp;
	NSMutableDictionary *dict;
	NSMutableData *coord = nil;
	NSMutableDictionary *clients = nil;
	NSMutableDictionary *packetsPerChannel = nil;
	
	[_dataLock lock];
	
	wp = [_netView coord];
	if ([_coordinates count]) {
		BIValuePair *vp;
		struct signalCoords *pL;
		
		coord = [NSMutableData dataWithLength:[_coordinates count] * sizeof(struct signalCoords)];
		pL = (struct signalCoords *)[coord mutableBytes];
		NSEnumerator *e = [_coordinates keyEnumerator];
		
		while ((vp = [e nextObject])) {
			pL->strength = [[_coordinates objectForKey:vp] intValue];
			pL->x = [vp getX];
			pL->y = [vp getY];
			pL++;
		}
	}
	
	if ([aClients count]) {
		NSString *c;
		clients = [NSMutableDictionary dictionaryWithCapacity:[aClients count]];
		NSEnumerator *e = [aClients keyEnumerator];
		
		while ((c = [e nextObject]) != nil) {
			[clients setObject:[[aClients objectForKey:c] dataDictionary] forKey:c];
		}
	}

	if (_packets) {
		packetsPerChannel = [NSMutableDictionary dictionary];
		for (int i = 0; i <14; i++) {
			if (_packetsPerChannel[i]) {
				[packetsPerChannel setObject:[NSNumber numberWithInt:_packetsPerChannel[i]] forKey:[NSString stringWithFormat:@"%.2u", i]];
			}
		}
	}

	dict = [NSMutableDictionary dictionary];
	
	[dict setObject:[NSNumber numberWithInt:_maxSignal] forKey:@"maxSignal"];
	if (_curSignal > 0)  [dict setObject:[NSNumber numberWithInt:_curSignal] forKey:@"curSignal"];
	[dict setObject:[NSNumber numberWithInt:_type] forKey:@"type"];
	[dict setObject:[NSNumber numberWithInt:_isWep] forKey:@"encryption"];
	if (_packets > 0)  [dict setObject:[NSNumber numberWithInt:_packets] forKey:@"packets"];
	if (_dataPackets > 0)  [dict setObject:[NSNumber numberWithInt:_dataPackets] forKey:@"dataPackets"];
	[dict setObject:[NSNumber numberWithInt:_channel] forKey:@"channel"];
	[dict setObject:[NSNumber numberWithInt:_primaryChannel] forKey:@"originalChannel"];
	[dict setObject:[NSNumber numberWithInt:_netID] forKey:@"netID"];
	
	[dict setObject:[NSNumber numberWithBool:_liveCaptured] forKey:@"liveCaptured"];
	if (_bytes > 0) [dict setObject:[NSNumber numberWithDouble:_bytes] forKey:@"bytes"];
	
	if (_rateCount) [dict setObject:[NSData dataWithBytes:_rates length:_rateCount] forKey:@"rates"];
	
	if (wp._lat != 0) [dict setObject:[NSNumber numberWithFloat:wp._lat] forKey:@"lat"];
	if (wp._long != 0) [dict setObject:[NSNumber numberWithFloat:wp._long] forKey:@"long"];
	if (wp._elevation != 0) [dict setObject:[NSNumber numberWithFloat:wp._elevation] forKey:@"elev"];
	
	if (aLat  && [aLat  length]>0) [dict setObject:aLat forKey:@"latString"];
	if (aLong && [aLong length]>0) [dict setObject:aLong forKey:@"longString"];
	if (aElev && [aElev length]>0) [dict setObject:aElev forKey:@"elevString"];
	
	if (_ID) [dict setObject:_ID forKey:@"ID"];
	if (aFirstDate) [dict setObject:aFirstDate forKey:@"firstDate"];
	if (_SSID)  [dict setObject:_SSID forKey:@"SSID"];
	if (_SSIDs) [dict setObject:_SSIDs forKey:@"SSIDs"];
	if (_BSSID) [dict setObject:_BSSID forKey:@"BSSID"];
	if (_date)  [dict setObject:_date forKey:@"date"];
	if (_ivData[0])  [dict setObject:[_ivData[0] data] forKey:@"ivData0"];
	if (_ivData[1])  [dict setObject:[_ivData[1] data] forKey:@"ivData1"];
	if (_ivData[2])  [dict setObject:[_ivData[2] data] forKey:@"ivData2"];
	if (_ivData[3])  [dict setObject:[_ivData[3] data] forKey:@"ivData3"];
	if (_packetsLog && [_packetsLog count] > 0) [dict setObject:_packetsLog forKey:@"packetsLog"];
	if (_ARPLog && [_ARPLog count] > 0) [dict setObject:_ARPLog forKey:@"ARPLog"];
	if (_ACKLog && [_ACKLog count] > 0) [dict setObject:_ACKLog forKey:@"ACKLog"];
	if (_password)   [dict setObject:_password forKey:@"password"];
	if (aComment && [aComment length] > 0) [dict setObject:aComment forKey:@"comment"];
	
	if (clients) [dict setObject:clients forKey:@"clients"];
	if (coord) [dict setObject:coord forKey:@"coordinates"];
	if (packetsPerChannel) [dict setObject:packetsPerChannel forKey:@"packetsPerChannel"];
	
	[_dataLock unlock];

	return dict;
}

- (void)updateSettings:(NSNotification*)note {
    NSUserDefaults *sets = [NSUserDefaults standardUserDefaults];
    
    _avgTime = [[sets objectForKey:@"WaveNetAvgTime"]  intValue];
}

#pragma mark -

- (void)updateSSID:(NSString*)newSSID withSound:(bool)sound {
    int lVoice;
    NSString *lSentence;
    NSString *oc;
    const char *pc;
    unsigned int i;
    bool isHidden = YES;
    bool updatedSSID;
    
    if (newSSID==Nil || [newSSID isEqualToString:_SSID]) return;

	pc = [newSSID lossyCString];
	for (i = 0; i < [newSSID length]; i++) {
		if (pc[i]) {
			isHidden = NO;
			break;
		}
	}
	if ([newSSID length]==1 && pc[i]==32) isHidden = YES;
	
	if (!_SSID) updatedSSID = NO;
	else updatedSSID = YES;
	
	if (isHidden) {
		if (_SSID!=Nil) return; //we might have the real ssid already
		[WaveHelper secureReplace:&_SSID withObject:@""];
	} else {
		[WaveHelper secureReplace:&_SSID withObject:newSSID];
	}

	[_netView setName:_SSID];
	if (!_firstPacket) [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];

	if (updatedSSID) return;
	
	if (sound) {
		lVoice=[[NSUserDefaults standardUserDefaults] integerForKey:@"Voice"];
		if (lVoice) {
			switch(_isWep) {
				case encryptionTypeNone: 
						oc = NSLocalizedString(@"open", "for speech");
						break;
				case encryptionTypeWEP:
				case encryptionTypeWEP40:
				case encryptionTypeWPA:
						oc = NSLocalizedString(@"closed", "for speech");
						break;
				default: oc=@"";
			}
			lSentence=[NSString stringWithFormat: NSLocalizedString(@"found %@ network. SSID is %@", "this is for speech output"),
				oc, isHidden ? NSLocalizedString(@"hidden", "for speech"): [_SSID uppercaseString]];
			NS_DURING
				[WaveHelper speakSentence:[lSentence cString] withVoice:lVoice];
			NS_HANDLER
			NS_ENDHANDLER
		}
	}
}

- (void)generalEncounterStuff:(bool)onlineCapture {
    waypoint cp;
    GPSController *gpsc;
    BIValuePair *pV;
    NSNumber *v;
    NSString *s;
    
    if (onlineCapture) {
        gpsc = [WaveHelper gpsController];
        cp = [gpsc currentPoint];    
		//after the first packet we should play some sound 
		if (_date == Nil) {
			if (cp._lat != 100) {
				// we have a new network with a GPS position - initialise _netView
				_netView = [[NetView alloc] initWithNetwork:self];
				[_netView setWep:_isWep];
				if (_SSID==Nil) [_netView setName:_BSSID]; // use BSSID for map label
				else [_netView setName:_SSID];
				[_netView setCoord:cp];
			}
						
			if (_isWep >= encryptionTypeWEP) [[NSSound soundNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"WEPSound"]] play];
			else [[NSSound soundNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"noWEPSound"]] play];
			
			if (_isWep == encryptionTypeUnknown) [GrowlController notifyGrowlProbeRequest:@"" BSSID:_BSSID signal:_curSignal];
			if (_isWep == encryptionTypeNone) [GrowlController notifyGrowlOpenNetwork:@"" SSID:_SSID BSSID:_BSSID signal:_curSignal channel:_channel];
			if (_isWep == encryptionTypeWEP) [GrowlController notifyGrowlWEPNetwork:@"" SSID:_SSID BSSID:_BSSID signal:_curSignal channel:_channel];
			if (_isWep == encryptionTypeWEP40) [GrowlController notifyGrowlWEPNetwork:@"" SSID:_SSID BSSID:_BSSID signal:_curSignal channel:_channel];
			if (_isWep == encryptionTypeWPA) [GrowlController notifyGrowlWPANetwork:@"" SSID:_SSID BSSID:_BSSID signal:_curSignal channel:_channel];
			if (_isWep == encryptionTypeLEAP) [GrowlController notifyGrowlLEAPNetwork:@"" SSID:_SSID BSSID:_BSSID signal:_curSignal channel:_channel];
		} else if (_SSID != nil && ([_date timeIntervalSinceNow] < -120.0)) {
			int lVoice=[[NSUserDefaults standardUserDefaults] integerForKey:@"Voice"];
			if (lVoice) {
				NSString * lSentence = [NSString stringWithFormat: NSLocalizedString(@"Reencountered network. SSID is %@", "this is for speech output"),
					[_SSID length] == 0 ? NSLocalizedString(@"hidden", "for speech"): [_SSID uppercaseString]];
				NS_DURING
					[WaveHelper speakSentence:[lSentence cString] withVoice:lVoice];
				NS_HANDLER
				NS_ENDHANDLER
			}
		}
		
		[WaveHelper secureReplace:&_date withObject:[NSDate date]];

        if (cp._lat!=100) {
            pV = [BIValuePair new];
            [pV setPairFromWaypoint:cp];
            v = [_coordinates objectForKey:pV];
            if ((v==Nil) || ([v intValue]<_curSignal))
                [_coordinates setObject:[NSNumber numberWithInt:_curSignal] forKey:pV];
            [pV release];
			if(_curSignal>=_maxSignal || ([aLat floatValue] == 0)) {
				if(!_netView) {
					// we didn't have a GPS position when this was first found, so initialise _netView now
					NSLog(@"First GPS fix for net %@ - initialising",_BSSID);
					_netView = [[NetView alloc] initWithNetwork:self];
					[_netView setWep:_isWep];
					if (_SSID==Nil) [_netView setName:_BSSID]; // use BSSID for map label
					else [_netView setName:_SSID];
				}
				gpsc = [WaveHelper gpsController];
				s = [gpsc NSCoord];
				if (s) [WaveHelper secureReplace:&aLat withObject:s];
				s = [gpsc EWCoord];
				if (s) [WaveHelper secureReplace:&aLong withObject:s];
				s = [gpsc ElevCoord];
				if (s) [WaveHelper secureReplace:&aElev withObject:s];
				[_netView setCoord:cp];
			}
        }
    }
    
    if(_curSignal>=_maxSignal) _maxSignal=_curSignal;
    
    if (!_liveCaptured) _liveCaptured = onlineCapture;
    _gotData = onlineCapture;
}

- (void) mergeWithNet:(WaveNet*)net {
    int temp;
    networkType tempType;
    encryptionType encType;
    int* p;
    
    temp = [net maxSignal];
    if (_maxSignal < temp) {
        _maxSignal = temp;
        [WaveHelper secureReplace:&aLat  withObject:[net latitude]];
        [WaveHelper secureReplace:&aLong withObject:[net longitude]];
		[WaveHelper secureReplace:&aElev withObject:[net elevation]];
    }
    
    if ([_date compare:[net lastSeenDate]] == NSOrderedDescending) {
        _curSignal = [net curSignal];
        
        if ([net channel]) _channel = [net channel];
        _primaryChannel = [net originalChannel];
        
        tempType = [net type];
        if (tempType != networkTypeUnknown) _type = tempType;
        
        encType = [net wep];
        if (encType != encryptionTypeUnknown) _isWep = encType;
        
        temp = [net channel];
        if (temp) _channel = temp;
        
        if ([net rawSSID]) [self updateSSID:[net rawSSID] withSound:NO];
        if ([net SSIDs]) [WaveHelper secureReplace:&_SSIDs withObject:[net SSIDs]];
		
        [WaveHelper secureReplace:&_date withObject:[net lastSeenDate]];
        if (![[net comment] isEqualToString:@""]) [WaveHelper secureReplace:&aComment withObject:[net comment]];
    }
    
    if ([aFirstDate compare:[net firstSeenDate]] == NSOrderedAscending)  [WaveHelper secureReplace:&aFirstDate withObject:[net firstSeenDate]];
        
    _packets +=     [net packets];
    _dataPackets += [net dataPackets];
    
    if (!_liveCaptured) _liveCaptured = [net liveCaptured];
    
    p = [net packetsPerChannel];
    for(int x=0;x<14;x++) {
        _packetsPerChannel[x] += p[x];
        if (_packetsPerChannel[x] == p[x]) //the net we merge with has some channel, we did not know about
            [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    }
    
    _bytes += [net dataCount];
    
    [_dataLock lock];
    
    [WaveHelper addDictionary:[net coordinates] toDictionary:_coordinates];
    
    //add all those unique ivs to the log file
    WaveWeakContainer **ivData = [net ivData];
    if (_ivData[0]) [_ivData[0] addData:[ivData[0] data]];
    else _ivData[0] = [[WaveWeakContainer alloc] initWithData:[ivData[0] data]];
    if (_ivData[1]) [_ivData[1] addData:[ivData[1] data]];
    else _ivData[1] = [[WaveWeakContainer alloc] initWithData:[ivData[1] data]];
    if (_ivData[2]) [_ivData[2] addData:[ivData[2] data]];
    else _ivData[2] = [[WaveWeakContainer alloc] initWithData:[ivData[2] data]];
    if (_ivData[3]) [_ivData[3] addData:[ivData[3] data]];
    else _ivData[3] = [[WaveWeakContainer alloc] initWithData:[ivData[3] data]];
    
    [_packetsLog addObjectsFromArray:[net cryptedPacketsLog]];
    //sort them so that the smallest packet is in front of the array => faster cracking
    [_packetsLog sortUsingFunction:lengthSort context:Nil];

    [_dataLock unlock];
}

- (void)parsePacket:(WavePacket*) w withSound:(bool)sound {
    NSString *clientid;
    WaveClient *lWCl;
    encryptionType wep;
    unsigned int bodyLength;
    UInt8 *body;
    
    _packets++;
	_cacheValid = NO;
	
    if (!_ID) {
        _ID = [[w IDString] retain];
        [w ID:_rawID];
    }
    
    _curSignal = [w signal];
    
    _channel=[w channel];
    _bytes+=[w length];
    if ((_packetsPerChannel[_channel]==0) && (!_firstPacket))
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    _packetsPerChannel[_channel]++;

    //statistical data for the traffic view
    if (sound) {
		if (!_graphInit) {
			graphData = new (struct graphStruct);
			_graphInit = YES;
			memset(graphData, 0, sizeof(struct graphStruct));
		}
        graphData->trafficData[graphLength] += [w length];
        graphData->packetData[graphLength] += 1;
        curSignalData += _curSignal;
        curPacketData++;
        curTrafficData += [w length];
    }
    
    if (_BSSID==Nil) {
        _BSSID=[[NSString stringWithString:[w BSSIDString]] retain];
        [w BSSID:_rawBSSID];
    }
    
    wep = [w wep];
    if (wep != encryptionTypeUnknown) {
        if (_isWep<wep || ([w type] == IEEE80211_TYPE_MGT && wep != encryptionTypeUnknown && _isWep!=wep && _isWep!=encryptionTypeLEAP)) {
            _isWep=wep;	//check if wep is enabled
            [_netView setWep:_isWep];
        }
    }
    if ([w netType]) _type=[w netType];	//gets the type of network
    
    [_dataLock lock];
    
    //do some special parsing depending on the packet type
    switch ([w type]) {
        case IEEE80211_TYPE_DATA: //Data frame                        
            _dataPackets++;
            body = [w framebody];
            bodyLength = [w bodyLength];
            
            if (_isWep > encryptionTypeNone && bodyLength > 3) memcpy(_IV, body, 3);	//sets the last IV thingy
            
            if (_isWep==encryptionTypeWEP || _isWep==encryptionTypeWEP40) {
                
                if (bodyLength>10) { //needs to have a fcs, an iv and two bytes of data at least
                    
                    //this packet might be interesting for password checking, use the packet if we do not have enough, or f it is smaller than our smallest
                    if ([_packetsLog count]<20 || [(NSString*)[_packetsLog objectAtIndex:0] length] > bodyLength) {
                        [_packetsLog addObject:[NSData dataWithBytes:[w framebody] length:bodyLength]];
                        //sort them so that the smallest packet is in front of the array => faster cracking
                        [_packetsLog sortUsingFunction:lengthSort context:Nil];
                    }

                    //log those packets for reinjection attack
                    if (bodyLength == ARP_SIZE || bodyLength == ARP_SIZE_PADDING) {
                        if ([[w clientToID] isEqualToString:@"FF:FF:FF:FF:FF:FF"]) {
                            [_ARPLog addObject:[NSData dataWithBytes:[w frame] length:[w length]]];
							if ([_ARPLog count] > 100) [_ARPLog removeObjectAtIndex:0];
						}
                    }
                    if (([_ACKLog count]<20)&&((bodyLength>=TCPACK_MIN_SIZE)||(bodyLength<=TCPACK_MAX_SIZE))) {
                        [_ACKLog addObject:[NSData dataWithBytes:[w frame] length:[w length]]];
                    }
                    
                    if (body[3] <= 3) { //record the IV for a later weak key attack
                        if (_ivData[body[3]] == nil) {
							_ivData[body[3]] = [[WaveWeakContainer alloc] init];
							NSAssert(_ivData[body[3]], @"unable to allocate weak container");
						}
                        @synchronized (_ivData[body[3]]) {
                            [_ivData[body[3]] setBytes:&body[4] forIV:&body[0]];
                        }
                    }
                }
            }
            break;
        case IEEE80211_TYPE_MGT:        //this is a management packet
			if ([w SSIDs]) [WaveHelper secureReplace:&_SSIDs withObject:[w SSIDs]];
			[self updateSSID:[w SSID] withSound:sound]; //might contain SSID infos
            
			if ([w primaryChannel]) _primaryChannel = [w primaryChannel];
			if ([w subType] == IEEE80211_SUBTYPE_BEACON) _rateCount = [w getRates:_rates];
    }

    //update the clients to out client array
    //if they are not in add them
    clientid=[w clientToID];
    if (clientid!=Nil) {
        lWCl=[aClients objectForKey:clientid];
        if (lWCl==nil) {
            lWCl=[[WaveClient alloc] init];
            [aClients setObject:lWCl forKey:clientid];
            [aClientKeys addObject:clientid];  
            [lWCl release];        
        }
        [lWCl parseFrameAsIncoming:w];
    }
    clientid=[w clientFromID];
    if (clientid!=Nil) {
        lWCl=[aClients objectForKey:clientid];
        if (lWCl==nil) {
            lWCl=[[WaveClient alloc] init];
            [aClients setObject:lWCl forKey:clientid];
            [aClientKeys addObject:clientid];
            [lWCl release];              
        }
        [lWCl parseFrameAsOutgoing:w];
    }
    
    [self generalEncounterStuff:sound];
    
    if (_firstPacket) {
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
        _firstPacket = NO;
    }
    
    [_dataLock unlock];
}

- (void)parseAppleAPIData:(NSDictionary*)info {
    encryptionType wep;
    const char *mac;
	int flags;
	
	NSParameterAssert(info);
	
	_cacheValid = NO;
	
    if (!_ID) {
        mac = (const char*)[[info objectForKey:@"BSSID"] bytes];
		NSAssert([[info objectForKey:@"BSSID"] length] == 6, @"BSSID length is not 6");
        memcpy(_rawID, mac, 6);
		memcpy(_rawBSSID, mac, 6);

        _ID = [[NSString stringWithFormat:@"%.2X%.2X%.2X%.2X%.2X%.2X", _rawID[0], _rawID[1], _rawID[2],
                _rawID[3], _rawID[4], _rawID[5]] retain];
        _BSSID = [[NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", _rawBSSID[0], _rawBSSID[1], _rawBSSID[2],
                _rawBSSID[3], _rawBSSID[4], _rawBSSID[5]] retain];
    }
        
    _curSignal = [[info objectForKey:@"signal"] intValue] - [[info objectForKey:@"noise"] intValue];
    if (_curSignal<0) _curSignal = 0;
    
    _primaryChannel = _channel = [[info objectForKey:@"channel"] intValue];
    if (_packetsPerChannel[_channel]==0) {
        if (!_firstPacket) [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
        _packetsPerChannel[_channel] = 1;
    }
    
    //statistical data for the traffic view
    //not much though
    curSignalData += _curSignal;
    curPacketData++;
	
	flags = [[info objectForKey:@"capability"] intValue];
    
	if (CFBooleanGetValue((CFBooleanRef)[info objectForKey:@"isWPA"])) {
		wep = encryptionTypeWPA;
	} else {
		wep = (flags & IEEE80211_CAPINFO_PRIVACY_LE) ? encryptionTypeWEP : encryptionTypeNone;
    }
	
	if (_isWep != wep) {
        _isWep = wep;	//check if wep is enabled
        [_netView setWep:_isWep];
    }
    
    if (flags & IEEE80211_CAPINFO_ESS_LE) {
        _type = networkTypeManaged;
    } else if (flags & IEEE80211_CAPINFO_IBSS_LE) {
        _type = networkTypeAdHoc;
    }

    [_dataLock lock];
    [self updateSSID:[info objectForKey:@"name"] withSound:YES];
    [self generalEncounterStuff:YES];
    
    if (_firstPacket) {
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
        _firstPacket = NO;
    }
    
    [_dataLock unlock];
}

#pragma mark -

- (bool)noteFinishedSweep:(int)num {
    // shuffle the values around in the aYield array
    bool ret;
    BIValuePair *pV;
    waypoint cp;
    
    graphLength = num;

    if (curPacketData) {
        curSignalData/=curPacketData;
        ret = NO;
    } else if ([[NSDate date] timeIntervalSinceDate:_date]>1 && _gotData) {
        cp = [[WaveHelper gpsController] currentPoint];
       
        if (cp._lat!=100) {
            [_dataLock lock];
            pV = [[BIValuePair alloc] init];
            [pV setPairFromWaypoint:cp];
            [_coordinates setObject:[NSNumber numberWithInt:0] forKey:pV];
            [pV release];
            [_dataLock unlock];
        }

        curSignalData=0;
        _curSignal=0;
        ret = YES;	//the net needs an update
        _gotData = NO;
    } else {
        return NO;
    }
    
    
	if (!_graphInit) {
		graphData = new (struct graphStruct);
		_graphInit = YES;
		memset(graphData, 0, sizeof(struct graphStruct));
	}
	
	// set the values we collected
    graphData->trafficData[graphLength] = curTrafficData;
    graphData->packetData[graphLength] = curPacketData;
    graphData->signalData[graphLength] = curSignalData;

    curTraffic = curTrafficData;
    curTrafficData = 0;
    curPackets = curPacketData;
    curPacketData = 0;
    curSignalData = 0;
    
    int x = num - 120;

    recentTraffic = 0;
    recentPackets = 0;
    recentSignal = 0;
    
	if(x < 0) x = 0;
    while(x < num) {
        recentTraffic += graphData->trafficData[x];
        recentPackets += graphData->packetData[x];
        recentSignal  += graphData->signalData[x];
            x++;
    }
    
    if(graphLength >= MAX_YIELD_SIZE) {
        memcpy(graphData->trafficData, graphData->trafficData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData->trafficData[MAX_YIELD_SIZE] = 0;

        memcpy(graphData->packetData, graphData->packetData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData->packetData[MAX_YIELD_SIZE] = 0;

        memcpy(graphData->signalData, graphData->signalData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData->signalData[MAX_YIELD_SIZE] = 0;
    }
 
	_cacheValid = NO;
    return ret;
}

- (void)setVisible:(BOOL)visible {
	[_netView setFiltered: !visible];
}

#pragma mark -

- (struct graphStruct)graphData {
    return *graphData;
}
- (NSDictionary*)getClients {
    return aClients;
}
- (NSArray*)getClientKeys {
    return aClientKeys;
}
- (encryptionType)wep { 
    return _isWep;
}
- (NSString *)ID {
    return _ID;
}
- (NSString *)BSSID {
    if (_BSSID==Nil) return NSLocalizedString(@"<no bssid>", "for tunnels");
    return _BSSID;
}
- (NSString *)SSID {
	NSString *ssid;
    if (_SSID==Nil) {
        switch (_type) {
        case networkTypeTunnel:
            ssid = NSLocalizedString(@"<tunnel>", "the ssid for tunnels");
			break;
		case networkTypeLucentTunnel:
            ssid = NSLocalizedString(@"<lucent tunnel>", "ssid for lucent tunnels");
			break;
		case networkTypeProbe:
            ssid = NSLocalizedString(@"<any ssid>", "the any ssid for probe nets");
			break;
        default:
            ssid = @"<no ssid>";
        }
    } else if ([_SSID isEqualToString:@""]) {
        ssid = (_type == networkTypeProbe ? 
            NSLocalizedString(@"<any ssid>", "the any ssid for probe nets") : 
            NSLocalizedString(@"<hidden ssid>", "hidden ssid")
        );
	} else {
		ssid = _SSID;
	}
	if ([_SSIDs count]) {
		return [NSString stringWithFormat:@"%@ (%@)", ssid, [_SSIDs componentsJoinedByString:@", "]];
	} else {
		return ssid;
	}
}
- (NSString *)rawSSID {
    return [_SSID isEqualToString:@""] ? nil : _SSID;
}
- (NSArray *)SSIDs {
	return _SSIDs;
}
- (NSString *)date {
    return [NSString stringWithFormat:@"%@", _date]; //return [_date descriptionWithCalendarFormat:@"%H:%M %d-%m-%y" timeZone:nil locale:nil];
}
- (NSDate*)lastSeenDate {
    return _date;
}
- (NSString *)firstDate {
    return [NSString stringWithFormat:@"%@", aFirstDate]; //[aFirstDate descriptionWithCalendarFormat:@"%H:%M %d-%m-%y" timeZone:nil locale:nil];
}
- (NSDate *)firstSeenDate {
    return aFirstDate;
}
- (NSString *)getIP {
    if (_IPAddress) {
        return _IPAddress;
    }
    return nil;
}
- (NSString *)data {
    return [WaveHelper bytesToString: _bytes];
}
- (float)dataCount {
    return _bytes;
}
- (NSString *)getVendor {
    if (_vendor) return _vendor;
    _vendor=[[WaveHelper vendorForMAC:_BSSID] retain];
    return _vendor;
}
- (NSString*)rates {
	int i;
	NSMutableArray *a = [NSMutableArray array];
	for (i = 0; i < _rateCount; i++) {
		[a addObject:[NSNumber numberWithFloat:((float)(_rates[i] & 0x7F)) / 2]];
	}
	return [a componentsJoinedByString:@", "];
}
- (NSString*)comment {
    return aComment;
}
- (void)setComment:(NSString*)comment {
    [aComment release];
    aComment=[comment retain];
}
- (int)avgSignal {
    int sum = 0;
    int i, x, c;
    int max = (graphLength < _avgTime*4) ? graphLength : _avgTime*4;
    
    c=0;
    for (i=0; i<max; i++) {
        x = graphData->signalData[graphLength - i];
        if (x) {
            sum += x;
            c++;
        }
    }
    if (c==0) return 0;
    return sum / c;
}
- (int)curSignal {
    return _curSignal;
}
- (int)curPackets {
    return curPackets;
}
- (int)curTraffic {
    return curTraffic;
}
- (int)recentTraffic {
    return recentTraffic;
}
- (int)recentPackets {
    return recentPackets;
}
- (int)recentSignal {
    return recentSignal;
}
- (int)maxSignal {
    return _maxSignal;
}
- (int)channel {
    return _channel;
}
- (int)originalChannel {
    return _primaryChannel;
}
- (networkType)type {
    return _type;
}
- (void)setNetID:(int)netID {
    _netID = netID;
}
- (int)netID {
    return _netID;
}
- (int)packets {
    return _packets;
}
- (int)uniqueIVs {
    return [_ivData[0] count] + [_ivData[1] count] + [_ivData[2] count] + [_ivData[3] count];
}
- (int)dataPackets {
    return _dataPackets;
}
- (int*)packetsPerChannel {
    return _packetsPerChannel;
}
- (bool)liveCaptured {
    return _liveCaptured;
}
- (NSArray*)cryptedPacketsLog {
    return _packetsLog;
}
- (NSMutableArray*)arpPacketsLog {
    return _ARPLog;
}
- (NSMutableArray*)ackPacketsLog {
    return _ACKLog;
}
- (NSString*)key {
    if ((_password==Nil)&&(_isWep > encryptionTypeNone)) return NSLocalizedString(@"<unresolved>", "Unresolved password");
    return _password;
}
- (NSString*)lastIV {
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X", _IV[0], _IV[1], _IV[2]];
}
- (UInt8*)rawBSSID {
    return _rawBSSID;
}
- (UInt8*)rawID {
    return _rawID;
}
- (NSDictionary*)coordinates {
    return _coordinates;
}
- (WaveWeakContainer **)ivData {
    return _ivData;
}
- (BOOL)passwordAvailable {
    return _password != nil;
}

#pragma mark -

- (NSDictionary*)cache {
	NSString *enc, *type;
	NSDictionary *cache;
	
	if (_cacheValid) return _cache;
	
	switch (_isWep) {
		case encryptionTypeLEAP:
			enc = NSLocalizedString(@"LEAP", "table description");
			break;
		case encryptionTypeWPA:     
			enc = NSLocalizedString(@"WPA", "table description");
			break;
		case encryptionTypeWEP40:
			enc = NSLocalizedString(@"WEP-40", "table description");
			break;
		case encryptionTypeWEP:
			enc = NSLocalizedString(@"WEP", "table description");
			break;
		case encryptionTypeNone:
			enc = NSLocalizedString(@"NO", "table description");
			break;
		case encryptionTypeUnknown:
			enc = @"";
			break;
		default:
			enc = @"";
			NSAssert(NO, @"Encryption type invalid");
	}
   
	switch (_type) {
		case networkTypeUnknown:
			type = @"";
			break;
		case networkTypeAdHoc:
			type = NSLocalizedString(@"ad-hoc", "table description");
			break;
		case networkTypeManaged:
			type = NSLocalizedString(@"managed", "table description");
			break;
		case networkTypeTunnel:
			type = NSLocalizedString(@"tunnel", "table description");
			break;
		case networkTypeProbe:
			type = NSLocalizedString(@"probe", "table description");
			break;
		case networkTypeLucentTunnel:
			type = NSLocalizedString(@"lucent tunnel", "table description");
			break;
		default:
			type = @"";
			NSAssert(NO, @"Network type invalid");
	}
	
	cache = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%i", _netID], @"id",
		[self SSID], @"ssid",
		[self BSSID], @"bssid", 
		[NSString stringWithFormat:@"%i", _curSignal], @"signal",
		[NSString stringWithFormat:@"%i", [self avgSignal]], @"avgsignal",
		[NSString stringWithFormat:@"%i", _maxSignal], @"maxsignal",
		[NSString stringWithFormat:@"%i", _channel], @"channel",
		[NSString stringWithFormat:@"%i", _packets], @"packets",
		[self data], @"data",
		enc, @"wep",
		type, @"type",
		[NSString stringWithFormat:@"%@", _date], @"lastseen",
		nil
	];
	
	[WaveHelper secureReplace:&_cache withObject:cache];
	_cacheValid = YES;
	return _cache; 
}

#pragma mark -

- (bool)joinNetwork {
    WirelessContextPtr wi_context;
    NSString *error;
    NSString *password;
    NSMutableArray *a;
    
    WIErr err = WirelessAttach(&wi_context, 0);
    if (err) {
        error = NSLocalizedString(@"Could not attach to Airport device.", "Joining error");
        //@"Could not attach to Airport device. Note: Joining a network is not possible, if the Airport passive driver is used!"
        goto e1;
    }
    
    if (!_SSID || [_SSID isEqualToString:@""]) {
        error = NSLocalizedString(@"You cannot join a hidden network, before you reveal the SSID.", "Joining error");
        goto e2;
    }
    
    if (_isWep != encryptionTypeNone && _isWep != encryptionTypeUnknown) {
        if (!_password) {
            error = NSLocalizedString(@"You do not have a password for this network.", "Joining error");
            goto e2;
        }
        
        if (_isWep == encryptionTypeWPA) {
            a = [NSMutableArray arrayWithArray:[_password componentsSeparatedByString:@" "]];
            [a removeLastObject]; [a removeLastObject]; [a removeLastObject]; //delete the for client stuff
            
            password = [a componentsJoinedByString:@" "];
            
            err = WirelessJoin8021x(wi_context, (CFStringRef)_SSID, (CFStringRef)password); 
        } else {
            password = [[_password componentsSeparatedByString:@" "] objectAtIndex:0]; //strip out the "for KeyID stuff"
            password = [NSString stringWithFormat:@"0x%@", [[password stringByTrimmingCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]] lowercaseString]];
            err = WirelessJoinWEP(wi_context, (CFStringRef)_SSID, (CFStringRef)password);        
        }
        
    } else {
        err = WirelessJoin(wi_context, (CFStringRef)_SSID);
    }
    
    err = WirelessDetach(wi_context);

    return YES;
e2:
    err = WirelessDetach(wi_context);
e1:
    NSBeginAlertSheet(
        NSLocalizedString(@"Error joining Network", "title for join network dialog"), 
        OK, nil, nil, [WaveHelper mainWindow], nil, nil, nil, nil, 
        NSLocalizedString(@"KisMAC could not join the selected network, because of the following error: %@", "description for join network dialog"), 
        error
    );

    return NO;
}

#pragma mark -

- (NSString *)latitude {
    if (!aLat) return @"0.000000N";
    return aLat;
}
- (NSString *)longitude {
    if (!aLong) return @"0.000000E";
    return aLong;
}

- (NSString *)elevation {
    if (!aElev) return @"0";
    return aElev;
}

- (NSString*)crackError {
    return _crackErrorString;
}

#pragma mark -

// for display color in TrafficView
- (NSColor*)graphColor {
    return _graphColor;
}
- (void)setGraphColor:(NSColor*)newColor {
    [_graphColor autorelease];
    _graphColor = [newColor retain];
}

// for easy sorting by TrafficView
- (NSComparisonResult)compareSignalTo:(id)aNet {
    if (_curSignal == [aNet curSignal])
        return NSOrderedSame;
    if (_curSignal > [aNet curSignal])
        return NSOrderedAscending;
    return NSOrderedDescending;
}

- (NSComparisonResult)comparePacketsTo:(id)aNet {
    if (curPackets == [aNet curPackets])
        return NSOrderedSame;
    if (curPackets > [aNet curPackets])
        return NSOrderedAscending;
    return NSOrderedDescending;
}

- (NSComparisonResult)compareTrafficTo:(id)aNet {
    if (curTraffic == [aNet curTraffic])
        return NSOrderedSame;
    if (curTraffic > [aNet curTraffic])
        return NSOrderedAscending;
    return NSOrderedDescending;
}
- (NSComparisonResult)compareRecentTrafficTo:(id)aNet {
    if (recentTraffic == [aNet recentTraffic])
        return NSOrderedSame;
    if (recentTraffic > [aNet recentTraffic])
        return NSOrderedAscending;
    return NSOrderedDescending;
}
- (NSComparisonResult)compareRecentPacketsTo:(id)aNet {
    if (recentPackets == [aNet recentPackets])
        return NSOrderedSame;
    if (recentPackets > [aNet recentPackets])
        return NSOrderedAscending;
    return NSOrderedDescending;
}
- (NSComparisonResult)compareRecentSignalTo:(id)aNet {
    if (recentSignal == [aNet recentSignal])
        return NSOrderedSame;
    if (recentSignal > [aNet recentSignal])
        return NSOrderedAscending;
    return NSOrderedDescending;
}

#pragma mark -

inline int compValues(int v1, int v2) {
    if (v1 < v2) return NSOrderedAscending;
    else if (v1 > v2) return NSOrderedDescending;
    else return NSOrderedSame;
}

inline int compFloatValues(float v1, float v2) {
    if (v1 < v2) return NSOrderedAscending;
    else if (v1 > v2) return NSOrderedDescending;
    else return NSOrderedSame;
}

int idSort(WaveClient* w1, WaveClient* w2, int ascend) {
    int v1 = [[w1 ID] intValue];
    int v2 = [[w2 ID] intValue];
    return ascend * compValues(v1,v2);
}

int clientSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * [[w1 ID] compare:[w2 ID]];
}

int vendorSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * [[w1 vendor] compare:[w2 vendor]];
}

int signalSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * compValues( [w1 curSignal], [w2 curSignal]);
}

int recievedSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * compFloatValues([w1 recievedBytes], [w2 recievedBytes]);
}

int sentSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * compFloatValues([w1 sentBytes], [w2 sentBytes]);
}
int dateSort(WaveClient* w1, WaveClient* w2, int ascend) {
    return ascend * [[w1 rawDate] compare:[w2 rawDate]];
}
int ipSort(WaveClient* w1, WaveClient* w2, int ascend) {
    //we break the ips into sections and sort 
    int i, ndx = 0;
    NSArray *ip1 = [[w1 getIPAddress] componentsSeparatedByString:@"."];
    NSArray *ip2 = [[w2 getIPAddress] componentsSeparatedByString:@"."];
    if ([ip1 count] < 4) {
        return ascend * NSOrderedDescending;
    }
    else if ([ip2 count] < 4) {
        return ascend * NSOrderedAscending;
    }
    while(ndx < 4){
        i = compValues([[ip1 objectAtIndex:ndx] intValue], [[ip2 objectAtIndex:ndx]intValue]);
        if (i == NSOrderedSame) {
            ndx++;
        }
        else break;
    }
    return ascend * i;
}

typedef int (*SORTFUNC)(id, id, void *);

- (void) sortByColumn:(NSString*)ident order:(bool)ascend {
    bool sorted = YES;
    SORTFUNC sf;
    int ret;
    unsigned int w, x, y, _sortedCount, a;
    
    if      ([ident isEqualToString:@"id"])     sf = (SORTFUNC)idSort;
    else if ([ident isEqualToString:@"client"]) sf = (SORTFUNC)clientSort;
    else if ([ident isEqualToString:@"vendor"]) sf = (SORTFUNC)vendorSort;
    else if ([ident isEqualToString:@"signal"]) sf = (SORTFUNC)signalSort;
    else if ([ident isEqualToString:@"recieved"]) sf=(SORTFUNC)recievedSort;
    else if ([ident isEqualToString:@"sent"])   sf = (SORTFUNC)sentSort;
    else if ([ident isEqualToString:@"lastseen"]) sf=(SORTFUNC)dateSort;
    else if ([ident isEqualToString:@"ipa"])      sf=(SORTFUNC)ipSort;
    else {
        NSLog(@"Unknown sorting column. This is a bug and should never happen.");
        return;
    }

    a = (ascend ? 1 : -1);
    
    [_dataLock lock];
    
    _sortedCount = [aClientKeys count];
    
    for (y = 1; y <= _sortedCount; y++) {
        for (x = y - 1; x < (_sortedCount - y); x++) {
            w = x + 1;
            ret = (*sf)([aClients objectForKey:[aClientKeys objectAtIndex:x]], [aClients objectForKey:[aClientKeys objectAtIndex:w]], (void*)a);
            if (ret == NSOrderedDescending) {
                sorted = NO;
                
                //switch places
                [aClientKeys exchangeObjectAtIndex:x withObjectAtIndex:w];
                [[aClients objectForKey:[aClientKeys objectAtIndex:x]] wasChanged];
                [[aClients objectForKey:[aClientKeys objectAtIndex:w]] wasChanged];
            }
        }
        
        if (sorted) break;
        sorted = YES;
        
        for (x = (_sortedCount - y); x >= y; x--) {
            w = x - 1;
            ret = (*sf)([aClients objectForKey:[aClientKeys objectAtIndex:w]], [aClients objectForKey:[aClientKeys objectAtIndex:x]], (void*)a);
            if (ret == NSOrderedDescending) {
                sorted = NO;
                
                //switch places
                [aClientKeys exchangeObjectAtIndex:x withObjectAtIndex:w];
                [[aClients objectForKey:[aClientKeys objectAtIndex:x]] wasChanged];
                [[aClients objectForKey:[aClientKeys objectAtIndex:w]] wasChanged];
            }
        }
        
        if (sorted) break;
        sorted = YES;
    }
        
    [_dataLock unlock];
}

#pragma mark -
#pragma mark WPA/LEAP cracking
#pragma mark -

- (int)capturedEAPOLKeys {
	int keys = 0;
	unsigned int i;
	
    for (i = 0; i < [aClientKeys count]; i++) {
        if ([[aClients objectForKey:[aClientKeys objectAtIndex:i]] eapolDataAvailable]) keys++;
    }
	return keys;
}

- (int)capturedLEAPKeys {
    int keys = 0;
    unsigned int i;
	
	for (i = 0; i < [aClientKeys count]; i++) {
        if ([[aClients objectForKey:[aClientKeys objectAtIndex:i]] leapDataAvailable]) keys++;
    }
	return keys;
}

#pragma mark -
#pragma mark Reinjection stuff
#pragma mark -

- (void)doReinjectWithScanner:(WaveScanner*)scanner {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *error;
    int i = 0;
	
    [scanner retain];
    [WaveHelper secureRelease:&_crackErrorString];
    
    while (YES) {
        [_im setStatusField:NSLocalizedString(@"Test suitable reinjection packets", "For Reinjection")];
         
        error = [scanner tryToInject:self];
        if (!error) {
            [_im terminateWithCode:1];
            //look here!!!
            break; //we are injecting
        }
        
        if ([error length]) { //something stupid happend
            _crackErrorString = [error retain];
            [_im terminateWithCode:-1];
            break;
        }
        
		if ([_im canceled]) {
            [_im terminateWithCode:0];
            break;
        }
        
        if ([_ARPLog count] == [_ACKLog count] == 0) {
            if (i > 20) {
				_crackErrorString = [NSLocalizedString(@"The networks seems to be not reacting.", "Reinjection error") retain];
				[_im terminateWithCode:-1];
				break;
			} else {
				[_im setStatusField:NSLocalizedString(@"Waiting for interesting packets...", "For Reinjection")];
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:20]];
				i++;
			}
        }
    }
    
	[scanner release];
    [[NSNotificationCenter defaultCenter] postNotificationName:KisMACCrackDone object:self];
    [pool release];
}

- (void)reinjectWithImportController:(ImportController*)im andScanner:(id)scanner {
    _im = im;
    
    [NSThread detachNewThreadSelector:@selector(doReinjectWithScanner:) toTarget:self withObject:scanner];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_dataLock lock];
    [_ID release];
    [_SSID release];
	[_SSIDs release];
    [_BSSID release];
    [_date release];
    [aFirstDate release];
    [_vendor release];
    [_password release];
    [_packetsLog release];
    [_ARPLog release];
    [_ACKLog release];
    [_ivData[0] release];
    [_ivData[1] release];
    [_ivData[2] release];
    [_ivData[3] release];
    [aClients release];
    [aClientKeys release];
    [aComment release];
    [aLat release];
    [aLong release];
    [aElev release];
	[_cache release];
	
	[_netView removeFromSuperView];
    [_netView release];
    [_coordinates release];
    [_dataLock unlock];
    [_dataLock release];
    [_crackErrorString release];
    
	if (_graphInit) delete graphData;
	
    [super dealloc];
}

@end
