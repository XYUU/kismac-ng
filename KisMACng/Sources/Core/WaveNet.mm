/*
        
        File:			WaveNet.mm
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

#import <AppKit/NSSound.h>
#import <BIGeneric/BIGeneric.h>
#import "WaveNet.h"
#import "WaveCracker.h"
#import "WaveClient.h"
#import "WaveHelper.h"
#import "80211b.h"
#import "WaveNetWPACrack.h"
#import "WaveNetLEAPCrack.h"
#import "WaveNetWPACrackAltivec.h"
#import "WaveScanner.h"
#import "KisMACNotifications.h"

#define AMOD(x, y) ((x) % (y) < 0 ? ((x) % (y)) + (y) : (x) % (y))
#define N 256

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
    self = [super init];
    
    if (!self) return nil;
    
    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];
    _netView = [[NetView alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
    [_netView setNetwork:self];
    
    aID = nil;
    
    aWeak=[[NSMutableDictionary dictionaryWithCapacity:13] retain];
    aPacketsLog=[[NSMutableArray arrayWithCapacity:20] retain];
    aARPLog=[[NSMutableArray arrayWithCapacity:20] retain];
    aACKLog=[[NSMutableArray arrayWithCapacity:20] retain];
    aClients=[[NSMutableDictionary dictionary] retain];
    aClientKeys=[[NSMutableArray array] retain];
    aComment=[[NSString stringWithString:@""] retain];
    aLat = [[NSString stringWithString:@""] retain];
    aLong = [[NSString stringWithString:@""] retain];
    aElev = [[NSString stringWithString:@""] retain];
    _coordinates = [[NSMutableDictionary dictionary] retain];
    aNetID=netID;

    _gotData = NO;
    recentTraffic = 0;
    curTraffic = 0;
    curPackets = 0;
    aCurSignal = 0;
    aChannel = 0;
    _originalChannel = 0;
    curTrafficData = 0;
    curPacketData = 0;
    memset(graphData.trafficData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
    memset(graphData.packetData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
    memset(graphData.signalData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
    
    _SSID = Nil;
    _firstPacket = YES;
    _liveCaptured = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    waypoint wp;
    int bssid[6];
    
    if ( [coder allowsKeyedCoding] ) {
        if ([coder decodeObjectForKey:@"aFirstDate"] == Nil) {
            NSLog(@"Invalid net, dropping!");
            return Nil;
        }
        
        self = [self init];
        if (!self) return nil;
    
        _dataLock = [[NSRecursiveLock alloc] init];
        [_dataLock lock];
        aChannel = [coder decodeIntForKey:@"aChannel"];
        _originalChannel = [coder decodeIntForKey:@"originalChannel"];
        aNetID=[coder decodeIntForKey:@"aNetID"];
        _packets=[coder decodeIntForKey:@"aPackets"];
        aMaxSignal=[coder decodeIntForKey:@"aMaxSignal"];
        aCurSignal=[coder decodeIntForKey:@"aCurSignal"];
        _type=(networkType)[coder decodeIntForKey:@"aType"];
        _isWep = (encryptionType)[coder decodeIntForKey:@"aIsWep"];
        _weakPackets=[coder decodeIntForKey:@"aWeakPackets"];
        _dataPackets=[coder decodeIntForKey:@"aDataPackets"];
        _liveCaptured=[coder decodeBoolForKey:@"_liveCaptured"];;
        
        for(int x=0; x<14; x++)
            _packetsPerChannel[x]=[coder decodeIntForKey:[NSString stringWithFormat:@"_packetsPerChannel%i",x]];
        
        aBytes=[coder decodeDoubleForKey:@"aBytes"];
        wp._lat =[coder decodeDoubleForKey:@"a_Lat"];
        wp._long=[coder decodeDoubleForKey:@"a_Long"];
	wp._elevation=[coder decodeDoubleForKey:@"a_Elev"];
        
        aLat = [[coder decodeObjectForKey:@"aLat"] retain];
        aLong = [[coder decodeObjectForKey:@"aLong"] retain];
	aElev = [[coder decodeObjectForKey:@"aElev"] retain];
        
        aID=[[coder decodeObjectForKey:@"aID"] retain];
        if (aID!=Nil && sscanf([aID cString], "%2X%2X%2X%2X%2X%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) {
            NSLog(@"Error could not decode ID %@!", aID);
        }
        
        for (int x=0; x<6; x++)
            aRawID[x] = bssid[x];
        
        _SSID=[[coder decodeObjectForKey:@"aSSID"] retain];
        aBSSID=[[coder decodeObjectForKey:@"aBSSID"] retain];
        if (![aBSSID isEqualToString:@"<no bssid>"]) {
            if (aBSSID!=Nil && sscanf([aBSSID cString], "%2X:%2X:%2X:%2X:%2X:%2X", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5])!=6) 
                NSLog(@"Error could not decode BSSID %@!", aBSSID);
            for (int x=0; x<6; x++)
                aRawBSSID[x] = bssid[x];
        } else {
             for (int x=0; x<6; x++)
                aRawBSSID[x] = bssid[0];
        }
        aDate=[[coder decodeObjectForKey:@"aDate"] retain];
        aFirstDate=[[coder decodeObjectForKey:@"aFirstDate"] retain];
        aWeak=[[coder decodeObjectForKey:@"aWeak"] retain];
        aPacketsLog=[[coder decodeObjectForKey:@"aPacketsLog"] retain];
        aARPLog=[[coder decodeObjectForKey:@"aARPLog"] retain];
        aACKLog=[[coder decodeObjectForKey:@"aACKLog"] retain];
        _password=[[coder decodeObjectForKey:@"aPassword"] retain];
        aComment=[[coder decodeObjectForKey:@"aComment"] retain];
        _coordinates=[[coder decodeObjectForKey:@"_coordinates"] retain];
        
        aClients=[[coder decodeObjectForKey:@"aClients"] retain];
        aClientKeys=[[coder decodeObjectForKey:@"aClientKeys"] retain];
        
        if (!aWeak) aWeak=[[NSMutableDictionary dictionaryWithCapacity:13] retain];
        if (!aPacketsLog) aPacketsLog=[[NSMutableArray arrayWithCapacity:20] retain];
        if (!aARPLog) aARPLog=[[NSMutableArray arrayWithCapacity:20] retain];
        if (!aACKLog) aACKLog=[[NSMutableArray arrayWithCapacity:20] retain];
        if (!aClients) aClients=[[NSMutableDictionary dictionary] retain];
        if (!aClientKeys) aClientKeys=[[NSMutableArray array] retain];
        if (!aComment) aComment=[[NSString stringWithString:@""] retain];
        if (!aLat) aLat = [[NSString stringWithString:@""] retain];
        if (!aLong) aLong = [[NSString stringWithString:@""] retain];
        if (!aElev) aElev = [[NSString stringWithString:@""] retain];
        if (!_coordinates) _coordinates = [[NSMutableDictionary dictionary] retain];
        
        if (_originalChannel == 0) _originalChannel = aChannel;
        _gotData = NO;
        
        _netView = [[NetView alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
        [_netView setNetwork:self];
        [_netView setWep:_isWep];
        [_netView setName:_SSID];
        [_netView setCoord:wp];
        
        _firstPacket = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
        [self updateSettings:nil];
        [_dataLock unlock];
    } else {
        NSLog(@"Cannot decode this way");
        return nil;
    }
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
    &aMaxSignal,
    &flags, &channelbits, &interval) < 9) {
        NSLog(@"line in backup file is corrupt or not compatible");
        [self release];
        return Nil;
    }

    if(ssid[strlen(ssid) - 1] == ' ') ssid[strlen(ssid) - 1] = '\0';

    _dataLock = [[NSRecursiveLock alloc] init];
    [_dataLock lock];
    
    if (strcmp(temp_bss, "IBSS") == 0)          _type = networkTypeAdHoc;
    else if (strcmp(temp_bss, "ad-hoc") == 0)   _type = networkTypeAdHoc;
    else if (strcmp(temp_bss, "BSS") == 0)      _type = networkTypeManaged;
    else if (strcmp(temp_bss, "TUNNEL") == 0)   _type = networkTypeTunnel;
    else if (strcmp(temp_bss, "PROBE") == 0)    _type = networkTypeProbe;
    else if (strcmp(temp_bss, "LTUNNEL") == 0)  _type = networkTypeLucentTunnel;
    else _type = networkTypeUnknown;

    _isWep = (flags & 0x0010) ? encryptionTypeWEP : encryptionTypeNone;

    aDate = [[NSDate dateWithString:[NSString stringWithFormat:@"%@ %.2d:%.2d:%.2d +0000", date, hour, min, sec]] retain];
    aFirstDate = [aDate retain];
    
    aLat  = [[NSString stringWithFormat:@"%f%c", ns_coord, ns_dir] retain];
    aLong = [[NSString stringWithFormat:@"%f%c", ew_coord, ew_dir] retain];
    _SSID = [[NSString stringWithCString: ssid] retain];

    aID = [[NSString stringWithFormat:@"%2X%2X%2X%2X%2X%2X", bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]] retain];
    aBSSID = [[NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]] retain];
    for (int x=0; x<6; x++)
        aRawID[x] = bssid[x];
    
    wp._lat  = ns_coord * (ns_dir == 'N' ? 1.0 : -1.0);
    wp._long = ew_coord * (ew_dir == 'E' ? 1.0 : -1.0);
    wp._elevation = 0;

    _netView = [[NetView alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
    [_netView setNetwork:self];
    [_netView setWep:_isWep];
    [_netView setName:_SSID];
    [_netView setCoord:wp];
    
    aWeak = [[NSMutableDictionary dictionaryWithCapacity:13] retain];
    aPacketsLog = [[NSMutableArray arrayWithCapacity:20] retain];
    aARPLog  = [[NSMutableArray arrayWithCapacity:20] retain];
    aACKLog  = [[NSMutableArray arrayWithCapacity:20] retain];
    aClients = [[NSMutableDictionary dictionary] retain];
    aClientKeys = [[NSMutableArray array] retain];
    aComment = [[NSString stringWithString:@""] retain];
    aElev = [[NSString stringWithString:@""] retain];
    _coordinates = [[NSMutableDictionary dictionary] retain];
    aNetID = 0;

    _gotData = NO;
    _liveCaptured = NO;
    recentTraffic = 0;
    curTraffic = 0;
    curPackets = 0;
    aCurSignal = 0;
    curTrafficData = 0;
    curPacketData = 0;
    memset(graphData.trafficData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
    memset(graphData.packetData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
    memset(graphData.signalData,0,(MAX_YIELD_SIZE + 1) * sizeof(int));
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:KisMACUserDefaultsChanged object:nil];
    [self updateSettings:nil];
    [_dataLock unlock];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    waypoint wp;
    if ([coder allowsKeyedCoding]) {
        NS_DURING
            [_dataLock lock];
            [coder encodeInt:aMaxSignal forKey:@"aMaxSignal"];
            [coder encodeInt:aCurSignal forKey:@"aCurSignal"];
            [coder encodeInt:_type forKey:@"aType"];
            [coder encodeInt:_isWep forKey:@"aIsWep"];
            [coder encodeInt:_packets forKey:@"aPackets"];
            [coder encodeInt:_weakPackets forKey:@"aWeakPackets"];
            [coder encodeInt:_dataPackets forKey:@"aDataPackets"];
            [coder encodeInt:aChannel forKey:@"aChannel"];
            [coder encodeInt:_originalChannel forKey:@"originalChannel"];
            [coder encodeInt:aNetID forKey:@"aNetID"];
            [coder encodeBool:_liveCaptured forKey:@"_liveCaptured"];
            
            for(int x=0;x<14;x++)
                [coder encodeInt:_packetsPerChannel[x] forKey:[NSString stringWithFormat:@"_packetsPerChannel%i",x]];
                
            [coder encodeDouble:aBytes forKey:@"aBytes"];
            
            wp = [_netView coord];
            [coder encodeFloat:wp._lat forKey:@"a_Lat"];
            [coder encodeFloat:wp._long forKey:@"a_Long"];
	    [coder encodeFloat:wp._elevation forKey:@"a_Elev"];
            
            [coder encodeObject:aLat forKey:@"aLat"];
            [coder encodeObject:aLong forKey:@"aLong"];
	    [coder encodeObject:aElev forKey:@"aElev"];
            
            [coder encodeObject:aID forKey:@"aID"];
            [coder encodeObject:_SSID forKey:@"aSSID"];
            [coder encodeObject:aBSSID forKey:@"aBSSID"];
            [coder encodeObject:aDate forKey:@"aDate"];
            [coder encodeObject:aFirstDate forKey:@"aFirstDate"];
            [coder encodeObject:aWeak forKey:@"aWeak"];
            [coder encodeObject:aPacketsLog forKey:@"aPacketsLog"];
            [coder encodeObject:aARPLog forKey:@"aARPLog"];
            [coder encodeObject:aACKLog forKey:@"aACKLog"];
            [coder encodeObject:_password forKey:@"aPassword"];
            [coder encodeObject:aComment forKey:@"aComment"];
            [coder encodeObject:_coordinates forKey:@"_coordinates"];
            
            [coder encodeObject:aClients forKey:@"aClients"];
            [coder encodeObject:aClientKeys forKey:@"aClientKeys"];
            [_dataLock unlock];
        NS_HANDLER
            NSLog(@"Warning an exception was raised during save of aClients, please send the resulting kismac file to mick@binaervarianz.de");
        NS_ENDHANDLER
    } else {
        NSLog(@"Cannot encode this way");
    }
    return;
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

    pc = [newSSID cString];
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
        if (_SSID!=Nil) return; //we might have the real bssid already
        [WaveHelper secureReplace:&_SSID withObject:@""];
    } else {
        [WaveHelper secureReplace:&_SSID withObject:newSSID];
    }
    
    [_netView setName:_SSID];
    if (!_firstPacket) [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];

    if (updatedSSID) return;
    
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

- (void)generalEncounterStuff:(bool)onlineCapture {
    waypoint cp;
    GPSController *gpsc;
    BIValuePair *pV;
    NSNumber *v;
    NSString *s;
    
    //after the first packet we should play some sound 
    if (aDate == Nil) {
        if (_SSID==Nil) [_netView setName:aBSSID]; //draw BSSID into the map
        
        //lucent plays an extra role
        //if ([aBSSID isEqualToString:@"00:00:00:00:00:00"]&&(_SSID==Nil))
        //    [self updateSSID:[NSString stringWithString:NSLocalizedString(@"<lucent tunnel>", "ssid for lucent tunnels")] withSound:onlineCapture];
        
        if (onlineCapture) { //sound?
            if (_isWep >= encryptionTypeWEP) [[NSSound soundNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"WEPSound"]] play];
            else [[NSSound soundNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"noWEPSound"]] play];
        }
    }
    
    [aDate release];
    aDate = [[NSDate date] retain];
    if (!aFirstDate)
        aFirstDate = [[NSDate date] retain];


    if (onlineCapture) {
        gpsc = [WaveHelper gpsController];
        cp = [gpsc currentPoint];    
        if (cp._lat!=0 && cp._long!=0) {
            pV = [[BIValuePair alloc] init];
            [pV setPairFromWaypoint:cp];
            v = [_coordinates objectForKey:pV];
            if ((v==Nil) || ([v intValue]<aCurSignal))
                [_coordinates setObject:[NSNumber numberWithInt:aCurSignal] forKey:pV];
            [pV release];
        }
    }
    
    if(aCurSignal>=aMaxSignal) {
        aMaxSignal=aCurSignal;
        if (onlineCapture) {
            gpsc = [WaveHelper gpsController];
            s = [gpsc NSCoord];
            if (s) [WaveHelper secureReplace:&aLat withObject:s];
            s = [gpsc EWCoord];
            if (s) [WaveHelper secureReplace:&aLong withObject:s];
            s = [gpsc ElevCoord];
            if (s) [WaveHelper secureReplace:&aElev withObject:s];
            if (cp._lat!=0 && cp._long!=0) [_netView setCoord:cp];
        }
    }
    
    if (!_liveCaptured) _liveCaptured = onlineCapture;
    _gotData = onlineCapture;
}

- (void) mergeWithNet:(WaveNet*)net {
    int temp;
    networkType tempType;
    encryptionType encType;
    int* p;
    id key;
    NSDictionary *dict;
    NSMutableDictionary *mdict;
    NSEnumerator *e;
    
    temp = [net maxSignal];
    if (aMaxSignal < temp) {
        aMaxSignal = temp;
        [WaveHelper secureReplace:&aLat  withObject:[net latitude]];
        [WaveHelper secureReplace:&aLong withObject:[net longitude]];
	[WaveHelper secureReplace:&aElev withObject:[net elevation]];
    }
    
    if ([aDate compare:[net lastSeenDate]] == NSOrderedDescending) {
        aCurSignal = [net curSignal];
        
        if ([net channel]) aChannel = [net channel];
        _originalChannel = [net originalChannel];
        
        tempType = [net type];
        if (tempType != networkTypeUnknown) _type = tempType;
        
        encType = [net wep];
        if (encType != encryptionTypeUnknown) _isWep = encType;
        
        temp = [net channel];
        if (temp) aChannel = temp;
        
        if ([net rawSSID]) [self updateSSID:[net rawSSID] withSound:NO];
        [WaveHelper secureReplace:&aDate withObject:[net lastSeenDate]];
        if (![[net comment] isEqualToString:@""]) [WaveHelper secureReplace:&aComment withObject:[net comment]];
    }
    
    if ([aFirstDate compare:[net firstSeenDate]] == NSOrderedAscending)  [WaveHelper secureReplace:&aFirstDate withObject:[net firstSeenDate]];
        
    _packets +=     [net packets];
    _weakPackets += [net weakPackets];
    _dataPackets += [net dataPackets];
    
    if (!_liveCaptured) _liveCaptured = [net liveCaptured];
    
    p = [net packetsPerChannel];
    for(int x=0;x<14;x++) {
        _packetsPerChannel[x] += p[x];
        if (_packetsPerChannel[x] == p[x]) //the net we merge with has some channel, we did not know about
            [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    }
    
    aBytes += [net dataCount];
    
    [_dataLock lock];
    
    [WaveHelper addDictionary:[net coordinates] toDictionary:_coordinates];
    
    //add all those weak packets to the log file
    dict = [net weakPacketsDict];
    e = [dict keyEnumerator];
    while(key = [e nextObject]) {
        mdict = [aWeak objectForKey:key];
        if (mdict)  [WaveHelper addDictionary:[dict objectForKey:key] toDictionary:mdict];
        else        [aWeak setObject:[dict objectForKey:key] forKey:key];
    }
    
    [aPacketsLog addObjectsFromArray:[net weakPacketsLog]];
    //sort them so that the smallest packet is in front of the array => faster cracking
    [aPacketsLog sortUsingFunction:lengthSort context:Nil];

    [_dataLock unlock];
}

- (void)parsePacket:(WavePacket*) w withSound:(bool)sound {
    NSString *clientid;
    WaveClient *lWCl;
    int lResolvType;
    unsigned int iv;
    NSNumber* num, *num2;
    NSMutableDictionary* x;
    encryptionType wep;
    unsigned int bodyLength;
    
    //int a, b;
    //UInt8 B;
    
    _packets++;
        
    if (!aID) {
        aID = [[w IDString] retain];
        [w ID:aRawID];
    }
    
    aCurSignal = [w signal];
    
    aChannel=[w channel];
    aBytes+=[w length];
    if ((_packetsPerChannel[aChannel]==0) && (!_firstPacket))
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    _packetsPerChannel[aChannel]++;

    //statistical data for the traffic view
    if (sound) {
        graphData.trafficData[graphLength] += [w length];
        graphData.packetData[graphLength] += 1;
        curSignalData += aCurSignal;
        curPacketData++;
        curTrafficData += [w length];
    }
    
    if (aBSSID==Nil) {
        aBSSID=[[NSString stringWithString:[w BSSIDString]] retain];
        [w BSSID:aRawBSSID];
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
            //is it WEP?
            if (_isWep > encryptionTypeNone) memcpy(aIV,[w framebody],3);	//sets the last IV thingy
            
            if (_isWep==encryptionTypeWEP || _isWep==encryptionTypeWEP40) {
                bodyLength = [w bodyLength];
                
                if (bodyLength>8) { //needs to have a fcs and an iv at least
                    
                    //this packet might be interesting for password checking, use the packet if we do not have enough, or f it is smaller than our smallest
                    if ([aPacketsLog count]<20 || [(NSString*)[aPacketsLog objectAtIndex:0] length] > bodyLength) {
                        [aPacketsLog addObject:[NSString stringWithCString:(const char*)([w framebody]) length:bodyLength]];
                        //sort them so that the smallest packet is in front of the array => faster cracking
                        [aPacketsLog sortUsingFunction:lengthSort context:Nil];
                    }

                    //log those packets for reinjection attack
                    if (([aARPLog count]<20)&&((bodyLength>=ARP_MIN_SIZE)&&(bodyLength<=ARP_MAX_SIZE))) {
                        if ([[w clientToID] isEqualToString:@"FF:FF:FF:FF:FF:FF"])
                            [aARPLog addObject:[NSString stringWithCString:(const char*)[w frame] length:[w length]]];
                    }
                    if (([aACKLog count]<20)&&((bodyLength>=TCPACK_MIN_SIZE)||(bodyLength<=TCPACK_MAX_SIZE))) {
                        [aACKLog addObject:[NSString stringWithCString:(const char*)[w frame] length:[w length]]];
                    }

                    lResolvType = [w isResolved];	//check whether the packet is weak
                    if (lResolvType>-1) {
                        UInt8 *p = [w framebody];
                        int a = (p[0] + p[1]) % N;
                        int b = AMOD((p[0] + p[1]) - p[2], N);

                        for(UInt8 B = 0; B < 13; B++) {
                          if((((0 <= a && a < B) ||
                             (a == B && b == (B + 1) * 2)) &&
                             (B % 2 ? a != (B + 1) / 2 : 1)) ||
                             (a == B + 1 && (B == 0 ? b == (B + 1) * 2 : 1)) ||
                             (p[0] == B + 3 && p[1] == N - 1) ||
                             (B != 0 && !(B % 2) ? (p[0] == 1 && p[1] == (B / 2) + 1) ||
                             (p[0] == (B / 2) + 2 && p[1] == (N - 1) - p[0]) : 0)) {
                                lResolvType = B;
                                
                                //if we dont have this type of packet make an array
                                num=[NSNumber numberWithInt:lResolvType];
                                x=[aWeak objectForKey:num];
                                if (x==Nil) {
                                    x=[[NSMutableDictionary dictionary] retain];
                                    [aWeak setObject:x forKey:num];
                                }
                                
                                //convert the iv to nextstep object
                                iv=aIV[0]*0x10000+aIV[1]*0x100+aIV[2];
                                num=[NSNumber numberWithUnsignedInt:iv];
                                num2=[x objectForKey:num];
                                if (num2==Nil) {
                                    //we dont have the iv => log it
                                    [x setObject:[NSNumber numberWithUnsignedChar:([w framebody][4] ^ 0xAA)] forKey:num];
                                    _weakPackets++;
                                }
                            }
                        }
                    }
                }
            }
            break;
        case IEEE80211_TYPE_MGT:        //this is a management packet
            [self updateSSID:[w ssid] withSound:sound]; //might contain SSID infos
            if ([w originalChannel]) _originalChannel = [w originalChannel];
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

- (void)parseAppleAPIData:(WirelessNetworkInfo*)info {
    encryptionType wep;
   
    if (!aID) {
        aID = [[NSString stringWithFormat:@"%.2X%.2X%.2X%.2X%.2X%.2X", info->macAddress[0], info->macAddress[1], info->macAddress[2],
                info->macAddress[3], info->macAddress[4], info->macAddress[5]] retain];
        memcpy(aRawID, info->macAddress, sizeof(info->macAddress));
    }
            
    aCurSignal = info->signal - info->noise;
    if (aCurSignal<0) aCurSignal = 0;
    
    aChannel = info->channel;
    _originalChannel = aChannel;
    if (_packetsPerChannel[aChannel]==0) {
        if (!_firstPacket) [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
        _packetsPerChannel[aChannel] = 1;
    }
    
    //statistical data for the traffic view
    //not much though
    curSignalData += aCurSignal;
    curPacketData++;
    
    if (aBSSID==Nil) {
        aBSSID = [[NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", info->macAddress[0], info->macAddress[1], info->macAddress[2],
                info->macAddress[3], info->macAddress[4], info->macAddress[5]] retain];
        memcpy(aRawBSSID, info->macAddress, sizeof(info->macAddress));
    }
    
    wep = (info->flags & IEEE80211_CAPINFO_PRIVACY_LE) ? encryptionTypeWEP : encryptionTypeNone;
    if (_isWep!=wep) {
        _isWep=wep;	//check if wep is enabled
        [_netView setWep:_isWep];
    }
    
    if (info->flags & IEEE80211_CAPINFO_ESS_LE) {
        _type = networkTypeManaged;
    } else if (info->flags & IEEE80211_CAPINFO_IBSS_LE) {
        _type = networkTypeAdHoc;
    }

    [_dataLock lock];
    [self updateSSID:[NSString stringWithCString:(char*)info->name length:info->nameLen] withSound:YES];
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
    } else if ([[NSDate date] timeIntervalSinceDate:aDate]>1 && _gotData) {
        cp = [[WaveHelper gpsController] currentPoint];
       
        if (cp._lat!=0 && cp._long!=0) {
            [_dataLock lock];
            pV = [[BIValuePair alloc] init];
            [pV setPairFromWaypoint:cp];
            [_coordinates setObject:[NSNumber numberWithInt:0] forKey:pV];
            [pV release];
            [_dataLock unlock];
        }

        curSignalData=0;
        aCurSignal=0;
        ret = YES;	//the net needs an update
        _gotData = NO;
    } else {
        return NO;
    }
    
    // set the values we collected
    graphData.trafficData[graphLength] = curTrafficData;
    graphData.packetData[graphLength] = curPacketData;
    graphData.signalData[graphLength] = curSignalData;

    curTraffic = curTrafficData;
    curTrafficData = 0;
    curPackets = curPacketData;
    curPacketData = 0;
    curSignalData = 0;
    
    int x = num - 120;

    recentTraffic = 0;
    recentPackets = 0;
    recentSignal = 0;
    if(x < 0)
        x = 0;
    while(x < num) {
        recentTraffic += graphData.trafficData[x];
        recentPackets += graphData.packetData[x];
        recentSignal += graphData.signalData[x];
            x++;
    }
    
    if(graphLength >= MAX_YIELD_SIZE) {
        memcpy(graphData.trafficData,graphData.trafficData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData.trafficData[MAX_YIELD_SIZE] = 0;

        memcpy(graphData.packetData,graphData.packetData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData.packetData[MAX_YIELD_SIZE] = 0;

        memcpy(graphData.signalData,graphData.signalData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        graphData.signalData[MAX_YIELD_SIZE] = 0;
    }
 
    return ret;
}

- (void)updatePassword {
    if ((_password==Nil)&&(_cracker!=Nil)) {
        _password=[[_cracker key] retain];
    }
}

#pragma mark -

- (struct graphStruct)graphData {
    return graphData;
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
    return aID;
}
- (NSString *)BSSID {
    if (aBSSID==Nil) return NSLocalizedString(@"<no bssid>", "for tunnels");
    return aBSSID;
}
- (NSString *)SSID {
    if (_SSID==Nil) {
        switch (_type) {
        case networkTypeTunnel:
            return NSLocalizedString(@"<tunnel>", "the ssid for tunnels");
        case networkTypeLucentTunnel:
            return NSLocalizedString(@"<lucent tunnel>", "ssid for lucent tunnels");
        case networkTypeProbe:
            return NSLocalizedString(@"<any ssid>", "the any ssid for probe nets");
        default:
            return @"<no ssid>";
        }
    }
    if ([_SSID isEqualToString:@""]) 
        return (_type == networkTypeProbe ? 
            NSLocalizedString(@"<any ssid>", "the any ssid for probe nets") : 
            NSLocalizedString(@"<hidden ssid>", "hidden ssid")
        );

    return _SSID;
}
- (NSString *)rawSSID {
    return [_SSID isEqualToString:@""] ? nil : _SSID;
}
- (NSString *)date {
    return [NSString stringWithFormat:@"%@", aDate]; //return [aDate descriptionWithCalendarFormat:@"%H:%M %d-%m-%y" timeZone:nil locale:nil];
}
- (NSDate*)lastSeenDate {
    return aDate;
}
- (NSString *)firstDate {
    return [NSString stringWithFormat:@"%@", aFirstDate]; //[aFirstDate descriptionWithCalendarFormat:@"%H:%M %d-%m-%y" timeZone:nil locale:nil];
}
- (NSDate *)firstSeenDate {
    return aFirstDate;
}
- (NSString *)data {
    return [WaveHelper bytesToString: aBytes];
}
- (float)dataCount {
    return aBytes;
}
- (NSString *)getVendor {
    if (aVendor) return aVendor;
    aVendor=[[WaveHelper vendorForMAC:aBSSID] retain];
    return aVendor;
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
        x = graphData.signalData[graphLength - i];
        if (x) {
            sum += x;
            c++;
        }
    }
    if (c==0) return 0;
    return sum / c;
}
- (int)curSignal {
    return aCurSignal;
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
    return aMaxSignal;
}
- (int)channel {
    return aChannel;
}
- (int)originalChannel {
    return _originalChannel;
}
- (networkType)type {
    return _type;
}
- (void)setNetID:(int)netID {
    aNetID = netID;
}
- (int)netID {
    return aNetID;
}
- (int)packets {
    return _packets;
}
- (int)weakPackets {
    return _weakPackets;
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
- (NSDictionary*)weakPacketsDict {
    return aWeak;
}
- (NSArray*)weakPacketsLog {
    return aPacketsLog;
}
- (NSMutableArray*)arpPacketsLog {
    return aARPLog;
}
- (NSMutableArray*)ackPacketsLog {
    return aACKLog;
}
- (NSString*)key {
    if ((_password==Nil)&&(_isWep > encryptionTypeNone)) return NSLocalizedString(@"<unresolved>", "Unresolved password");
    return _password;
}
- (NSString*)lastIV {
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X", aIV[0], aIV[1], aIV[2]];
}
- (UInt8*)rawBSSID {
    return aRawBSSID;
}
- (UInt8*)rawID {
    return aRawID;
}
- (NSDictionary*)coordinates {
    return _coordinates;
}
- (BOOL)passwordAvailable {
    return _password != nil;
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
    if (aCurSignal == [aNet curSignal])
        return NSOrderedSame;
    if (aCurSignal > [aNet curSignal])
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

- (void)doCrackWPAWithWordlists:(NSArray*)wordlists {
    unsigned int i;
    NSString *file;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    for (i = 0; i < [wordlists count]; i++) {
        file = [wordlists objectAtIndex: i];
        if ([WaveHelper isAltiVecAvailable]) {
            if ([self crackWPAWithWordlistAltivec:[file stringByExpandingTildeInPath] andImportController:_im]) break;
        } else {
            if ([self crackWPAWithWordlist:[file stringByExpandingTildeInPath] andImportController:_im]) break;
        }
    }
    
    [_im terminateWithCode: (i == [wordlists count]) ? -1 : 0];
    [pool release];
}

- (BOOL)crackWPAWithImportController:(ImportController*) im {
    int keys;
    unsigned int i;
    NSOpenPanel *aOP;
    
    [WaveHelper secureRelease:&_crackErrorString];
    
    if (_isWep != encryptionTypeWPA) {
        _crackErrorString = [NSLocalizedString(@"The network is not WPA protected.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    if (!_SSID) {
        _crackErrorString = [NSLocalizedString(@"You need to reveal the SSID first!", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    if ([_SSID length] > 32) {
        _crackErrorString = [NSLocalizedString(@"The SSID is too long. This means it does not conform to WPA!", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }

    keys = 0;
    for (i = 0; i < [aClientKeys count]; i++) {
        if ([[aClients objectForKey:[aClientKeys objectAtIndex:i]] eapolDataAvailable]) keys++;
    }
    
    if (keys == 0) {
        _crackErrorString = [NSLocalizedString(@"KisMAC did not capture any authentication data.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    
    if (_password) {
        _crackErrorString = [NSLocalizedString(@"KisMAC did already reveal the password.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    
    aOP=[NSOpenPanel openPanel];
    [aOP setAllowsMultipleSelection:YES];
    [aOP setCanChooseFiles:YES];
    [aOP setCanChooseDirectories:NO];
    if ([aOP runModalForTypes:nil]==NSOKButton) {
        _im = im;
        [[aOP filenames] retain];
        [NSThread detachNewThreadSelector:@selector(doCrackWPAWithWordlists:) toTarget:self withObject:[aOP filenames]];
        return YES;
    }
    
    [im terminateWithCode:-2];
    return NO;
}

- (void)doCrackLEAPWithWordlists:(NSArray*)wordlists {
    unsigned int i;
    NSString *file;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    for (i = 0; i < [wordlists count]; i++) {
        file = [wordlists objectAtIndex: i];
        if ([self crackLEAPWithWordlist:[file stringByExpandingTildeInPath] andImportController:_im]) break;
    }

    [_im terminateWithCode: (i == [wordlists count]) ? -1 : 0];
    [pool release];
}

- (BOOL)crackLEAPWithImportController:(ImportController*) im {
    int keys;
    unsigned int i;
    NSOpenPanel *aOP;
    
    [WaveHelper secureRelease:&_crackErrorString];
    
    if (_isWep != encryptionTypeLEAP) {
        _crackErrorString = [NSLocalizedString(@"The network is not LEAP protected.", @"Error description for LEAP crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    keys = 0;
    for (i = 0; i < [aClientKeys count]; i++) {
        if ([[aClients objectForKey:[aClientKeys objectAtIndex:i]] leapDataAvailable]) keys++;
    }
    
    if (keys == 0) {
        _crackErrorString = [NSLocalizedString(@"KisMAC did not capture any authentication data.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    if (_password) {
        _crackErrorString = [NSLocalizedString(@"KisMAC did already reveal the password.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }
    
    
    aOP=[NSOpenPanel openPanel];
    [aOP setAllowsMultipleSelection:YES];
    [aOP setCanChooseFiles:YES];
    [aOP setCanChooseDirectories:NO];
    if ([aOP runModalForTypes:nil]==NSOKButton) {
        _im = im;
        [[aOP filenames] retain];
        [NSThread detachNewThreadSelector:@selector(doCrackLEAPWithWordlists:) toTarget:self withObject:[aOP filenames]];
        return YES;
    }
    
    [im terminateWithCode: 1];
    return NO;
}
#pragma mark -
#pragma mark WEP attack
#pragma mark -

- (BOOL)crackWithKeyByteLength:(unsigned int)a breath:(unsigned int)b import:(ImportController*)im {
    if (_isWep != encryptionTypeWEP && _isWep != encryptionTypeWEP40) {
        _crackErrorString = [NSLocalizedString(@"The selected network is not WEP encrypted", @"Error description for cracking.") retain];
        [im terminateWithCode:-1];
        return NO;
    }

    if (_password) {
        _crackErrorString = [NSLocalizedString(@"KisMAC did already reveal the password.", @"Error description for WPA crack.") retain];
        [im terminateWithCode:-1];
        return NO;
    }

    if (_cracker==Nil) _cracker=[[WaveCracker alloc] init];
    _crackErrorString = [NSLocalizedString(@"The probabilistic attack was unsuccessful.", @"Error description for weak WEP crack.") retain];
    [_cracker crackWithKeyByteLength:a net:self breath:b import:im];
    
    return YES;
}

#pragma mark -
#pragma mark Reinjection stuff
#pragma mark -

- (void)doReinjectWithScanner:(WaveScanner*)scanner {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *error;
    
    [scanner retain];
    [WaveHelper secureRelease:&_crackErrorString];
    
    while (YES) {
        if ([_im canceled]) {
            [_im terminateWithCode:-2];
            break;
        }
        
        [_im setStatusField:NSLocalizedString(@"Reinjecting packets", "For Reinjection")];
         
        error = [scanner tryToInject:self];
        if (!error) {
            [_im terminateWithCode:0];
            break; //we are injecting
        }
        
        if ([error length]) { //something stupid happend
            _crackErrorString = [error retain];
            [_im terminateWithCode:-1];
            break;
        }
        
        //lets cause some ARP stuff to go off
        [_im setStatusField:NSLocalizedString(@"Deauthenticating clients.", "For Reinjection")];
        [scanner deauthenticateNetwork:self atInterval:0];
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        if ([aARPLog count] == [aACKLog count] == 0) {
            _crackErrorString = [NSLocalizedString(@"The networks seems to be not reacting.", "Reinjection error") retain];
            [_im terminateWithCode:-1];
            break;
        }
    }
    
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
    [_netView removeFromSuperview];

    [_dataLock lock];
    [aID release];
    [_SSID release];
    [aBSSID release];
    [aDate release];
    [aFirstDate release];
    [aVendor release];
    [_cracker release];
    [_password release];
    [aPacketsLog release];
    [aARPLog release];
    [aACKLog release];
    [aWeak release];
    [aClients release];
    [aClientKeys release];
    [aComment release];
    [aLat release];
    [aLong release];
    [aElev release];
    [_netView release];
    [_coordinates release];
    [_dataLock unlock];
    [_dataLock release];
    [_crackErrorString release];
    
    [super dealloc];
}

@end
