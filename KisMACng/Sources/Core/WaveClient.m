/*
        
        File:			WaveClient.m
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

#import "WaveClient.h"
#import "WaveHelper.h"
#import "WPA.h"

@implementation WaveClient

- (id)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if ( [coder allowsKeyedCoding] ) {
        aCurSignal=[coder decodeIntForKey:@"aCurSignal"];

        aRecievedBytes=[coder decodeDoubleForKey:@"aRecievedBytes"];
        aSentBytes=[coder decodeDoubleForKey:@"aSentBytes"];
        
        aID     = [[coder decodeObjectForKey:@"aID"] retain];
        aDate   = [[coder decodeObjectForKey:@"aDate"] retain];
        
        //WPA stuff
        _sNonce = [[coder decodeObjectForKey:@"sNonce"] retain];
        _aNonce = [[coder decodeObjectForKey:@"aNonce"] retain];
        _packet = [[coder decodeObjectForKey:@"packet"] retain];
        _MIC    = [[coder decodeObjectForKey:@"MIC"] retain];

        //LEAP stuff
        _leapUsername   = [[coder decodeObjectForKey:@"leapUsername"] retain];
        _leapChallenge  = [[coder decodeObjectForKey:@"leapChallenge"] retain];
        _leapResponse   = [[coder decodeObjectForKey:@"leapResponse"] retain];
        
        _changed = YES;
     } else {
        NSLog(@"Cannot decode this way");
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if ([coder allowsKeyedCoding]) {
        [coder encodeInt:aCurSignal forKey:@"aCurSignal"];
        
        [coder encodeDouble:aRecievedBytes forKey:@"aRecievedBytes"];
        [coder encodeDouble:aSentBytes forKey:@"aSentBytes"];

        [coder encodeObject:aID forKey:@"aID"];
        [coder encodeObject:aDate forKey:@"aDate"];
    
        //WPA stuff
        [coder encodeObject:_sNonce forKey:@"sNonce"];
        [coder encodeObject:_aNonce forKey:@"aNonce"];
        [coder encodeObject:_packet forKey:@"packet"];
        [coder encodeObject:_MIC    forKey:@"MIC"];

        //LEAP stuff
        [coder encodeObject:_leapUsername   forKey:@"leapUsername"];
        [coder encodeObject:_leapChallenge  forKey:@"leapChallenge"];
        [coder encodeObject:_leapResponse   forKey:@"leapResponse"];
    } else {
        NSLog(@"Cannot encode this way");
    }
    return;
}

#pragma mark -

- (void)wpaHandler:(WavePacket*) w {
    UInt8 nonce[WPA_NONCE_LENGTH];
    NSData *mic, *packet;
    
    if (![w isEAPPacket]) return;
    
    if ([w isWPAKeyPacket]) {
        switch ([w wpaCopyNonce:nonce]) {
            case wpaNonceANonce:
                NSLog(@"Detected WPA challenge for %@!", aID);
                [WaveHelper secureReplace:&_aNonce withObject:[NSData dataWithBytes:nonce length:WPA_NONCE_LENGTH]];
                break;
            case wpaNonceSNonce:
                NSLog(@"Detected WPA response for %@!", aID);
                [WaveHelper secureReplace:&_sNonce withObject:[NSData dataWithBytes:nonce length:WPA_NONCE_LENGTH]];
                break;
            case wpaNonceNone:
                break;
        }
        
        packet = [w eapolData];
        mic = [w eapolMIC];
        if (packet) [WaveHelper secureReplace:&_packet withObject:packet];
        if (mic)    [WaveHelper secureReplace:&_MIC    withObject:mic];
    } else if ([w isLEAPKeyPacket]) {
        switch ([w leapCode]) {
        case leapAuthCodeChallenge:
            if (!_leapUsername) [WaveHelper secureReplace:&_leapUsername  withObject:[w username]];
            if (!_leapChallenge) [WaveHelper secureReplace:&_leapChallenge withObject:[w challenge]];
            break;
        case leapAuthCodeResponse:
            if (!_leapResponse) [WaveHelper secureReplace:&_leapResponse  withObject:[w response]];
            break;
        case leapAuthCodeFailure:
            NSLog(@"Detected LEAP authentication failure for client %@! Username: %@. Deleting all collected auth data!", aID, _leapUsername);
            [WaveHelper secureRelease:&_leapUsername];
            [WaveHelper secureRelease:&_leapChallenge];
            [WaveHelper secureRelease:&_leapResponse];
            break;
        default:
            break;
        }
    }
}

-(void) parseFrameAsIncoming:(WavePacket*)w {
    if (!aID)
        aID=[[w clientToID] retain];

    aRecievedBytes+=[w length];
    _changed = YES;
    
    if (![w toDS]) [self wpaHandler:w]; //dont store it in the AP client
}

-(void) parseFrameAsOutgoing:(WavePacket*)w {
    if (!aID)
        aID=[[w clientFromID] retain];
    
    [WaveHelper secureReplace:&aDate withObject:[NSDate date]];
    
    aCurSignal=[w signal];
    aSentBytes+=[w length];    
    _changed = YES;
    
    if (![w fromDS]) [self wpaHandler:w]; //dont store it in the AP client
}

#pragma mark -

- (NSString *)ID {
    if (!aID) return NSLocalizedString(@"<unknown>", "unknown client ID");
    return aID;
}

- (NSString *)recieved {
    return [WaveHelper bytesToString: aRecievedBytes];
}

- (NSString *)sent {
    return [WaveHelper bytesToString: aSentBytes];
}

- (NSString *)vendor {
    if (_vendor) return _vendor;
    _vendor=[[WaveHelper vendorForMAC:aID] retain];
    return _vendor;
}

- (NSString *)date {
    if (aDate==Nil) return @"";
    else return [NSString stringWithFormat:@"%@", aDate]; //return [aDate descriptionWithCalendarFormat:@"%H:%M %d-%m-%y" timeZone:nil locale:nil];
}

#pragma mark -

- (float)recievedBytes {
    return aRecievedBytes;
}

- (float)sentBytes {
    return aSentBytes;
}

- (int)curSignal {
    if ([aDate compare:[NSDate dateWithTimeIntervalSinceNow:0.5]]==NSOrderedDescending) aCurSignal=0;
    return aCurSignal;
}

- (NSDate *)rawDate {
    return aDate;
}

#pragma mark -
#pragma mark WPA stuff
#pragma mark -

- (NSData *)sNonce {
    return _sNonce;
}

- (NSData *)aNonce {
    return _aNonce;
}

- (NSData *)eapolMIC {
    return _MIC;
}

- (NSData *)eapolPacket {
    return _packet;
}

- (NSData *)rawID {
    UInt8   ID8[6];
    int     ID32[6];
    int i;
    
    if (!aID) return Nil;
    
    if (sscanf([aID cString], "%2X:%2X:%2X:%2X:%2X:%2X", &ID32[0], &ID32[1], &ID32[2], &ID32[3], &ID32[4], &ID32[5]) != 6) return Nil;
    for (i = 0; i < 6; i++)
        ID8[i] = ID32[i];
    
    return [NSData dataWithBytes:ID8 length:6];
}

- (BOOL) eapolDataAvailable {
    if (_sNonce && _aNonce && _MIC && _packet) return YES;
    return NO;
}

#pragma mark -
#pragma mark LEAP stuff
#pragma mark -

- (NSData *)leapChallenge {
    return _leapChallenge;
}
- (NSData *)leapResponse {
    return _leapResponse;
}
- (NSString *)leapUsername {
    return _leapUsername;
}
- (BOOL) leapDataAvailable {
    if (_leapChallenge && _leapResponse && _leapUsername) return YES;
    return NO;
}

#pragma mark -

- (BOOL)changed {
    BOOL c = _changed;
    _changed = NO;
    return c;
}

- (void)wasChanged {
    _changed = YES;
}

#pragma mark -

-(void) dealloc {
    [aDate release];
    [aID release];
    [_vendor release];

    //WPA
    [_sNonce release];
    [_aNonce release];
    [_packet release];
    [_MIC release];
    
    //LEAP
    [_leapUsername  release];
    [_leapChallenge release];
    [_leapResponse  release];
}
@end
