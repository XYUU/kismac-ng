/*
        
        File:			WavePacket.mm
        Program:		KisMAC
	Author:			Michael Ro�berg
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

#import "WavePacket.h"
#import "WaveHelper.h"
#import "80211b.h"

#import <pcap.h>

#define AMOD(x, y) ((x) % (y) < 0 ? ((x) % (y)) + (y) : (x) % (y))
#define N 256

#define WPA_HEADER "\x00\x50\xf2\x01"

bool inline is8021xPacket(const UInt8* fileData) {
    if (fileData[0] == 0xAA &&
        fileData[1] == 0xAA &&
        fileData[2] == 0x03 &&
        fileData[3] == 0x00 &&
        fileData[4] == 0x00 &&
        (fileData[5] == 0x00 || fileData[5] == 0xf8) &&
        fileData[6] == 0x88 &&
        fileData[7] == 0x8e)
        
        return YES;
    else
        return NO;
}

@implementation WavePacket

//scans through variable length fields for ssid
-(void) parseTaggedData:(unsigned char*) packet length:(int) length {
    int len;
    char ssid[33];
	
    _originalChannel = 0;
    
    [WaveHelper secureRelease:&_SSID];
    while(length>2) {
        switch (*packet) {
        case IEEE80211_ELEMID_SSID:
            len=(*(packet+1));
            if ((length >= len+2) && (_SSID == Nil) && (len <= 32)) {
				memcpy(ssid, packet+2, len);
				ssid[len]=0;
				@try  {
					_SSID = [[NSString stringWithUTF8String:ssid] retain];
				}
				@catch (NSException *exception) {
					_SSID = [[NSString stringWithCString:(char*)(packet+2) length:len] retain];
				}
			}
            break;
        case IEEE80211_ELEMID_DSPARMS:
            len=(*(packet+1));
            if (len == 1 && length >= 3)
                _originalChannel = (UInt8)(*(packet+2));
            break;
        case IEEE80211_ELEMID_WPA:
            len=(*(packet+1));
            if (len > 4 && length >= len+2) {
                if(memcmp((packet+2), WPA_HEADER, 4) == 0)
                    _isWep = encryptionTypeWPA;
            }
            break;
        }
        
        packet++;
        length-=(*packet)+1;
        packet+=(*packet)+1;
    }
}

//this initializes the structure with a raw frame
- (bool)parseFrame:(WLFrame*) f {
    //WLCryptedFrame *cf;
    int i;
    UInt16 p;
    NSMutableArray *ar;
    
    if (f==NULL) return NO;
    
    [WaveHelper secureRelease:&_SSID];
    _netType = networkTypeUnknown;
    _isWep = encryptionTypeUnknown;
    _isEAP = NO;
    _rawFrame = (UInt8*)(f);
    _revelsKeyByte = -2;
    if (_frame) {
        delete [] _frame;
        _frame = NULL;
    }
    
    _type=(f->frameControl & IEEE80211_TYPE_MASK);
    _subtype=(f->frameControl & IEEE80211_SUBTYPE_MASK);
    _isToDS=((f->frameControl & IEEE80211_DIR_TODS) ? YES : NO);
    _isFrDS=((f->frameControl & IEEE80211_DIR_FROMDS) ? YES : NO);

    //the viha driver actually switches these fields
    //and macjack doesn't, so now it is the silence field
    aSignal=f->silence-f->signal;
    if (aSignal<0) aSignal=0;	

    aChannel=(f->channel>14 || f->channel<1 ? 1 : f->channel);
        
    //depending on the frame we have to figure the length of the header
    switch(_type) {
        case IEEE80211_TYPE_DATA:               //Data Frames
            if (_isToDS && _isFrDS) {
                _headerLength=30;               //WDS Frames are longer
                _netType = networkTypeTunnel;   //what can i say? it is a tunnel
            } else {
                _headerLength=24;               //3 macs in the header
                
                // if either the from or the to ap bit set we are managed
                if (_isToDS|_isFrDS) _netType = networkTypeManaged;
                else if (memcmp(&aMACAddress[12], "\x00\x00\x00\x00\x00\x00", 6)==0) _netType = networkTypeLucentTunnel;
                else _netType = networkTypeAdHoc;
            }
            
            _length=f->dataLen;	//this was prepared in kernel land
            
            if (_length >= 24 && is8021xPacket((UInt8*)(f+1))) {
                _isEAP = YES;
                
                if ([self isWPAKeyPacket]) _isWep = encryptionTypeWPA;
                else if ([self isLEAPKeyPacket]) _isWep = encryptionTypeLEAP;
                else if (f->frameControl & IEEE80211_WEP) _isWep = encryptionTypeWEP;     //is just WEP
                else _isWep = encryptionTypeNone;
            } else {
                if (f->frameControl & IEEE80211_WEP) _isWep = encryptionTypeWEP;     //is just WEP
                else _isWep = encryptionTypeNone;
            }
            break;            
        case IEEE80211_TYPE_CTL: //Control Frames
            switch(_subtype) {
                case IEEE80211_SUBTYPE_PS_POLL:
                case IEEE80211_SUBTYPE_RTS:
                    _headerLength=16;
                    break;
                case IEEE80211_SUBTYPE_CTS:
                case IEEE80211_SUBTYPE_ACK:
                    _headerLength=10;
                    break;
                default:
                    return NO;
            }
            _length=0;
            break;
        case IEEE80211_TYPE_MGT: //Management Frame
            _headerLength=24;
            _length=f->dataLen; //this was prepared in kernel land
            switch (_subtype) {
                case IEEE80211_SUBTYPE_PROBE_REQ:
                    if (memcmp(f->address3,"\xff\xff\xff\xff\xff\xff",6)==0) {
                        ar = [WaveHelper getProbeArrayForID:(char*)f->address2];
                        i = [[ar objectAtIndex:1] intValue];
                        if (i==-1) {
                            _netType = networkTypeProbe;
                            break;
                        }
                        if ([[NSDate date] timeIntervalSinceDate:[ar objectAtIndex:0]]>5) {
                            [ar replaceObjectAtIndex:0 withObject:[NSDate date]];
                            [ar replaceObjectAtIndex:1 withObject:[NSNumber numberWithInt:1]];
                        } else if (i>=15) { 
                            NSLog(@"WARNING!!! Recieved a Probe flood from %@. This usually means that this computer uses a cheap stumbler such as iStumbler, Macstumbler or Netstumbler!", [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", f->address2[0], f->address2[1], f->address2[2], f->address2[3], f->address2[4], f->address2[5]]);
                            [ar replaceObjectAtIndex:1 withObject:[NSNumber numberWithInt:-1]];
                            _netType = networkTypeProbe;
                        } else {
                            [ar replaceObjectAtIndex:1 withObject:[NSNumber numberWithInt:i+1]];
                        }
                        
                    }
                    break;
                case IEEE80211_SUBTYPE_PROBE_RESP:
                case IEEE80211_SUBTYPE_BEACON:
                    p=*((UInt16 *)(((char*)f)+sizeof(WLFrame)+10)); //offset to capabilities
                    _isWep=((p & IEEE80211_CAPINFO_PRIVACY) ? encryptionTypeWEP : encryptionTypeNone);
                    if (p & IEEE80211_CAPINFO_ESS) _netType = networkTypeManaged;
                    else if (p & IEEE80211_CAPINFO_IBSS) _netType = networkTypeAdHoc;
                    
                    
                    [self parseTaggedData:((unsigned char*)f)+sizeof(WLFrame)+12 length:_length-12]; //12 byte fixed info
                    break;
                case IEEE80211_SUBTYPE_ASSOC_REQ:
                    [self parseTaggedData:((unsigned char*)f)+sizeof(WLFrame)+4 length:_length-4]; //4 byte fixed info
                    break;
                case IEEE80211_SUBTYPE_REASSOC_REQ:
                    [self parseTaggedData:((unsigned char*)f)+sizeof(WLFrame)+10 length:_length-10]; //10 byte fixed info
                    break;
                case IEEE80211_SUBTYPE_DEAUTH:
                    NSLog(@"ATTENTION! Recieved deauthentication frame. You might want to check for other WiFi people.");
            }
            break;
        default:
            return NO;
    }
        

    //copy all those interesting MAC addresses
    memset(aMACAddress,0,30*sizeof(int));
    for (i=0;i<18;i++) aMACAddress[i]=f->address1[i];
    for (i=0;i<6 ;i++) aMACAddress[18+i]=f->address4[i];
    
    //important for pcap
    gettimeofday(&aCreationTime,NULL);
    
    return YES;        
}

#pragma mark -

// This function returns a unique net id for each packet. if it cannot be determined null. bssid is not useable because of tunnels
- (NSString*)IDString {
    int i=4, y, x[6];
    
    //if (_isToDS) return nil;
    
    switch (_type) {
        case IEEE80211_TYPE_MGT:
            //probe requests are BS
            if (_subtype!=IEEE80211_SUBTYPE_PROBE_REQ) i=2;
            else if (_netType == networkTypeProbe) i=1;
            break; 
        case IEEE80211_TYPE_CTL:
            if (_subtype==IEEE80211_SUBTYPE_PS_POLL) i=0;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) {
                if (_netType == networkTypeLucentTunnel) i=1;
                else i=2;
            }
            else if((_isToDS)&&(!_isFrDS)) i=0;
            else if((!_isToDS)&&(_isFrDS)) i=1;
            else for(y=0;y<6;y++) {
                if (aMACAddress[y]>aMACAddress[y+6]) { i=0; break; }
                else if (aMACAddress[y]<aMACAddress[y+6]) { i=1; break; }
            }
            break;
        default:
            break;
    }
    if (i==4) return nil;
    
    for (y=0;y<6;y++) x[y]=aMACAddress[(i*6)+y];
    return [NSString stringWithFormat:@"%.2X%.2X%.2X%.2X%.2X%.2X", x[0], x[1], x[2], x[3], x[4], x[5]];

}

//returns the the id of the sending client
- (NSString*)clientFromID {
    int i=4, y, x[6];

    switch (_type) {
        case IEEE80211_TYPE_MGT:
            i=1;
            break; 
        case IEEE80211_TYPE_CTL:
            if (_subtype==IEEE80211_SUBTYPE_PS_POLL) i=1;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) i=1;
            else if((_isToDS)&&(!_isFrDS)) i=1;
            else if((!_isToDS)&&(_isFrDS)) i=2;
            else i=3;
            break;
        default:
            break;
    }
    if (i==4) return Nil;
    
    for (y=0;y<6;y++) x[y]=aMACAddress[(i*6)+y];
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", x[0], x[1], x[2], x[3], x[4], x[5]];
}

//What can I say? returns the the id of the recieving client
- (NSString*)clientToID {
    int i=4, y, x[6];

    switch (_type) {
        case IEEE80211_TYPE_MGT:
            i=0;
            break;
        case IEEE80211_TYPE_CTL:
            //ps polls only have a transmitter
            if (_subtype!=IEEE80211_SUBTYPE_PS_POLL) i=0;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) i=0;
            else if((_isToDS)&&(!_isFrDS)) i=2;
            else if((!_isToDS)&&(_isFrDS)) i=0;
            else i=2;
            break;
        default:
            break;
    }
    if (i==4) return Nil;
    
    for (y=0;y<6;y++) x[y]=aMACAddress[(i*6)+y];
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", x[0], x[1], x[2], x[3], x[4], x[5]];
}

//What can I say? returns the bssid
- (NSString*)BSSIDString {
    int i=4, y, x[6];

    switch (_type) {
        case IEEE80211_TYPE_MGT:
            //probe requests are BS
            if (_subtype!=IEEE80211_SUBTYPE_PROBE_REQ) i=2;
            else if (_netType == networkTypeProbe) i=1;
            break; 
        case IEEE80211_TYPE_CTL:
            if (_subtype==IEEE80211_SUBTYPE_PS_POLL) i=0;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) {
                if (_netType == networkTypeLucentTunnel) i=1;
                else i=2;
            }
            else if((_isToDS)&&(!_isFrDS)) i=0;
            else if((!_isToDS)&&(_isFrDS)) i=1;
            break;
        default:
            break;
    }
    if (i==4) return @"<no bssid>";
    
    for (y=0;y<6;y++) x[y]=aMACAddress[(i*6)+y];
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", x[0], x[1], x[2], x[3], x[4], x[5]];
}

- (bool)BSSID:(UInt8*)bssid {
    int i=4, y;

    switch (_type) {
        case IEEE80211_TYPE_MGT:
            //probe requests are BS
            if (_subtype!=IEEE80211_SUBTYPE_PROBE_REQ) i=2;
            else if (_netType == networkTypeProbe) i=1;
            break; 
        case IEEE80211_TYPE_CTL:
            if (_subtype==IEEE80211_SUBTYPE_PS_POLL) i=0;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) {
                if (_netType == networkTypeLucentTunnel) i=1;
                else i=2;
            }
            else if((_isToDS)&&(!_isFrDS)) i=0;
            else if((!_isToDS)&&(_isFrDS)) i=1;
            break;
        default:
            break;
    }
    if (i==4) return NO;
    
    for (y=0;y<6;y++) bssid[y]=aMACAddress[(i*6)+y];
    return YES;
}

- (bool)ID:(UInt8*)netid {
    int i=4, y;
    
    switch (_type) {
        case IEEE80211_TYPE_MGT:
            //probe requests are BS
            if (_subtype!=IEEE80211_SUBTYPE_PROBE_REQ) i=2;
            else if (_netType == networkTypeProbe) i=1;
            break; 
        case IEEE80211_TYPE_CTL:
            if (_subtype==IEEE80211_SUBTYPE_PS_POLL) i=0;
            break;
        case IEEE80211_TYPE_DATA:
            if((!_isToDS)&&(!_isFrDS)) {
                if (_netType == networkTypeLucentTunnel) i=1;
                i=2;
            }
            else if((_isToDS)&&(!_isFrDS)) i=0;
            else if((!_isToDS)&&(_isFrDS)) i=1;
            else for(y=0;y<6;y++) {
                if (aMACAddress[y]>aMACAddress[y+6]) { i=0; break; }
                else if (aMACAddress[y]<aMACAddress[y+6]) { i=1; break; }
            }
            break;
        default:
            break;
    }
    if (i==4) return NO;
    
    for (y=0;y<6;y++) netid[y]=aMACAddress[(i*6)+y];
    return YES;
}

#pragma mark -

//writes the frame into the pcap file f
-(void)dump:(void*)f {
    if (!f) return; //this happens when dumping was switched on while scanning
    pcap_pkthdr h;

    memcpy(&h.ts,&aCreationTime,sizeof(struct timeval));
    h.caplen = _length+_headerLength;
    h.len    = h.caplen;

    if (!_frame) {
        _frame = (UInt8*) new char[_length+_headerLength];
        memcpy(_frame,((char*)_rawFrame)+sizeof(struct sAirportFrame),_headerLength);
        memcpy(((char*)_frame)+_headerLength,((char*)_rawFrame)+sizeof(WLFrame),_length);
    }
    
    pcap_dump((u_char*)f,&h,(u_char*)_frame);
}

-(id)init {
    if (self = [super init]) {
        memset(aMACAddress,0,30*sizeof(int));
        _frame = NULL;
    }
    return self;
}

-(void) dealloc {
    if (_frame) delete [] _frame;
    [super dealloc];
}

-(int)signal {
    return aSignal;
}
-(int)status {
    return aStatus;
}
-(int)silence {
    return aSilence;
}
- (int)length {
    return _length+_headerLength;
}
- (int)bodyLength {
    return _length;
}
- (int)channel {
    return aChannel;
}
- (int)type {
    return _type;
}
- (int)subType {
    return _subtype;
}
- (bool)fromDS {
    return _isFrDS;
}
- (bool)toDS {
    return _isToDS;
}
- (encryptionType)wep {
    return _isWep;
}
- (int)originalChannel {
    return _originalChannel;
}
- (networkType)netType {
    return _netType;
}
- (NSString*)ssid {
    return _SSID;
}
- (UInt8*) framebody {
    return _rawFrame + sizeof(WLFrame);
}
- (UInt8*) frame {
    if (!_frame) {
        _frame = (UInt8*) new char[_headerLength + _length];
        memcpy(_frame,                        (_rawFrame) + sizeof(struct sAirportFrame),_headerLength);
        memcpy(((char*)_frame)+_headerLength, (_rawFrame) + sizeof(WLFrame),             _length);
    }
    return _frame;
}
- (bool)isEAPPacket {
    return _isEAP;
}

#pragma mark -

//which keybyte will be reveled by this packet
//-1 if none
- (int)isResolved {
    unsigned char *p;
    
    if (_revelsKeyByte != -2) return _revelsKeyByte;
    
    if ((_isWep!=encryptionTypeWEP && _isWep!=encryptionTypeWEP40) || (_type!=IEEE80211_TYPE_DATA) || (_length<9)) {
        _revelsKeyByte = -1;
        return _revelsKeyByte;
    }
    
    p=(UInt8*)(_rawFrame+sizeof(WLFrame));
    
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
            //NSLog(@"We got a weak packet reveling byte: %u",B);
            _revelsKeyByte = B;
            return _revelsKeyByte;
        }
    }

    //NSLog(@"end of weak packet");
   
    _revelsKeyByte = -1;
    return _revelsKeyByte;
}

- (int)isResolved2 {
    unsigned char *p;
    unsigned char sum, k;
    
    if ((_isWep!=encryptionTypeWEP && _isWep!=encryptionTypeWEP40) || (_type!=IEEE80211_TYPE_DATA) || (_length<9)) return -1;
    
    p=(UInt8*)(_rawFrame+sizeof(WLFrame));
    
    if ((p[0]>3) && (p[2]>=254) && (p[1]+p[0]-p[2]==2)) 
            return 0;

    if (p[1] == 255 && p[0] > 2 && p[0] < 16) return p[0] - 3; //this is for the base line attack

    sum = p[0] + p[1];
    if (sum == 1) {
        if (p[2] <= 0x0A) return p[2] + 2;
        if (p[2] == 0xFF) return 0;
        return -1;
    } if (sum < 13) {
        k = 0xFE - p[2];
        if (sum == k) return k;
    }
    //k = 0xFE - p[2];
    //if (sum == k && (p[2] >= 0xF2 && p[2] <= 0xFE)) return k;

    return -1;
}

#pragma mark -
#pragma mark IP detection
#pragma mark -

// Patch Added by Dylan Neild 
// Detects and returns source IP and/or destination IP. 

// These Methods are internal methods... not for external use.

int detectLLCAndSNAP(UInt8 *fileData, int fileLength) {
    if (fileLength < 8)	
        return FALSE;
    else {
        if (fileData[0] == 0xAA &&
            fileData[1] == 0xAA &&
            fileData[2] == 0x03 &&
            fileData[3] == 0x00 &&
            fileData[4] == 0x00 &&
            fileData[5] == 0x00 &&
            fileData[6] == 0x08 &&
            fileData[7] == 0x00)
            
            return TRUE;
        else
            return FALSE;
    }
}

int detectIPVersion(UInt8 *fileData, int fileLength) {
    if (fileLength < 9)
        return -1;
    else 
        return (fileData[8] >> 4);
}

int detectIPHeaderLength(UInt8 *fileData, int fileLength) {
    
    unsigned char shiftLeft;
    
    if (fileLength < 9)
            return -1;
    else {
        shiftLeft = fileData[8] << 4;
        
        return (shiftLeft >> 4);
    }
}

int verifyIPv4Checksum(UInt8 *fileData, int fileLength) {
	
    long computedChecksum;
    unsigned char *dataPointer;
    int i, headerLength, headerLoop;
    
    headerLength = detectIPHeaderLength(fileData, fileLength);
    headerLoop = (headerLength * 4); 
    
    if (headerLength < 5) 
        return FALSE;
    else {	
        dataPointer = &fileData[8];
        computedChecksum = 0;
        
        for (i = 0; i < headerLoop; i=i+2) 
            computedChecksum = computedChecksum + ((fileData[8+i]<<8) + fileData[8+i+1]);
        
        computedChecksum = (computedChecksum & 0xffff) + (computedChecksum >> 16);
                        
        if (computedChecksum == 0xffff) 
            return TRUE;
        else
            return FALSE;
    }	
}

int isValidPacket(UInt8 *fileData, int fileLength) {
    if (detectLLCAndSNAP(fileData, fileLength) == TRUE) {
        // frame probably contains data. 
        
        if (detectIPVersion(fileData, fileLength) == 4) {
            // frame apparently contains an IPv4 header

            if (verifyIPv4Checksum(fileData, fileLength) == TRUE)
                return 4;
            else 
                return -1;
        }
        else if (detectIPVersion(fileData, fileLength) == 6) {
            // frame apparently contains an detects IPv6 header.
            // we don't actually do anything for this, as we don't 
            // currently support IPv6.
            // TODO add check for IPv6
            return 6;
        }
        else
            return -1;
    }
    else {
        // frame doesn't contain usable data.
        return -1;
    }
}

- (UInt8*) ipPacket {
    UInt8* body;
    
    if (_type != IEEE80211_TYPE_DATA) return nil;
    if (_isWep != encryptionTypeNone) return nil; // TODO decrypt if key is known. For later dissection
    
    body = [self framebody];
    if (isValidPacket(body, [self bodyLength]) != 4) return nil;
    return body + 8;
}

// Methods for external use.

- (NSString *)sourceIPAsString {
    int frameLength = [self bodyLength];
    
    if (isValidPacket(_rawFrame+sizeof(WLFrame), frameLength) == 4) 
        return [NSString stringWithFormat:@"%u.%u.%u.%u", _rawFrame[20]+sizeof(WLFrame), _rawFrame[21]+sizeof(WLFrame), _rawFrame[22]+sizeof(WLFrame), _rawFrame[23]+sizeof(WLFrame)];
    else
        return nil;
}

- (NSString *)destinationIPAsString {
    int frameLength = [self bodyLength];
    
    if (isValidPacket(_rawFrame+sizeof(WLFrame), frameLength) == 4)  
        return [NSString stringWithFormat:@"%u.%u.%u.%u", _rawFrame[24+sizeof(WLFrame)], _rawFrame[25+sizeof(WLFrame)], _rawFrame[26+sizeof(WLFrame)], _rawFrame[27+sizeof(WLFrame)]];
    else
        return nil;
}

- (unsigned char *)sourceIPAsData {
    int frameLength = [self bodyLength];
    unsigned char *targetAddress = (unsigned char *)malloc(sizeof(unsigned char) * 4);
    
    if (targetAddress == NULL) 
        return nil;
    else {
        if (isValidPacket(_rawFrame+sizeof(WLFrame), frameLength) == 4) {
            memcpy(&targetAddress, &_rawFrame[20 + sizeof(WLFrame)], 4);
            return targetAddress;
        }
        else
            return nil;
    }
}

- (unsigned char *)destinationIPAsData {
    int frameLength = [self bodyLength];
    unsigned char *targetAddress = (unsigned char *)malloc(sizeof(unsigned char) * 4);
    
    if (targetAddress == NULL) 
        return nil;
    else {
        if (isValidPacket(_rawFrame+sizeof(WLFrame), frameLength) == 4) {
            memcpy(&targetAddress, &_rawFrame[24+sizeof(WLFrame)], 4);
            return targetAddress;
        }
        else
            return nil;
    }
}

#pragma mark -
#pragma mark WPA stuff
#pragma mark -

- (bool)isWPAKeyPacket {
    if (!_isEAP) return NO;
    
    int frameLength = [self bodyLength];
    UInt8 *zeroNonce[WPA_NONCE_LENGTH];
    frame8021x *f;
    UInt16 flags;
    
    if (frameLength < 99) return NO;
    
    f = (frame8021x*)&_rawFrame[8+sizeof(WLFrame)];
    
    if (f->version != 1 ||      //version 1
        f->type != 3 ||         //should be a key
        _rawFrame[12+sizeof(WLFrame)] != 254)   //should be a WPA key
            return NO;
    
    flags = *((UInt16*)(&_rawFrame[13+sizeof(WLFrame)]));
    
    if (flags & WPA_FLAG_KEYTYPE == WPA_FLAG_KEYTYPE_GROUPWISE) return NO; //this is not interesting
    
    _wpaCipher = flags & WPA_FLAG_KEYCIPHER;
    switch (flags & (WPA_FLAG_MIC | WPA_FLAG_ACK | WPA_FLAG_INSTALL)) {
        case WPA_FLAG_ACK:  //only ack set
            _nonce = wpaNonceANonce;
            break;
        case WPA_FLAG_MIC:  //only mic set
            memset(zeroNonce, 0, WPA_NONCE_LENGTH);
            if (memcmp(zeroNonce, &_rawFrame[25+sizeof(WLFrame)], WPA_NONCE_LENGTH)) _nonce = wpaNonceSNonce;
            else  _nonce = wpaNonceNone;
            break;
        case WPA_FLAG_MIC | WPA_FLAG_ACK | WPA_FLAG_INSTALL:  //all set
            _nonce = wpaNonceANonce;
            break;
        default:
            _nonce = wpaNonceNone;
    }
    
    return YES;
}

- (int)wpaKeyCipher {
    return _wpaCipher;
}

- (wpaNoncePresent)wpaCopyNonce:(UInt8*)destNonce {
    if (destNonce) {
        memcpy(destNonce, &_rawFrame[25+sizeof(WLFrame)], WPA_NONCE_LENGTH);
    }
    
    return _nonce;
}

- (NSData*)eapolMIC {
    UInt16 flags = *((UInt16*)(&_rawFrame[13+sizeof(WLFrame)]));
    
    if ((flags & WPA_FLAG_MIC) == 0) return Nil; //no MIC present

    return [NSData dataWithBytes:&_rawFrame[81+8+sizeof(WLFrame)] length:WPA_EAP_MIC_LENGTH];
}

- (NSData*)eapolData {
    UInt16 flags = *((UInt16*)(&_rawFrame[13+sizeof(WLFrame)]));
    NSMutableData *md;
    
    if ((flags & WPA_FLAG_MIC) == 0) return Nil; //no MIC present

    md = [NSMutableData dataWithBytes:&_rawFrame[8+sizeof(WLFrame)] length:[self bodyLength] - 8];    //copy the whole key packet
    memset(&((UInt8*)[md mutableBytes])[81], 0, WPA_EAP_MIC_LENGTH);
    
    return md;
}

#pragma mark -
#pragma mark LEAP stuff
#pragma mark -

- (bool)isLEAPKeyPacket {
    if (!_isEAP) return NO;
    int frameLength = [self bodyLength];
    frame8021x  *f;
    frameLEAP   *l;
    int         userLength;
    
    f = (frame8021x*)&_rawFrame[8+sizeof(WLFrame)];
    l = (frameLEAP*) &f->data;
    
    if (f->version != 1 || 
        f->type != 0    || 
        l->type != 17   || //looking for LEAP
        l->version != 1) return NO;
    
    _leapCode = (leapAuthCode)l->code;
    switch (_leapCode) {
        case leapAuthCodeChallenge: //handle challenge
            userLength = l->length-16;
            if (frameLength-24 < userLength) return NO;
            [WaveHelper secureReplace:&_challenge   withObject:[NSData dataWithBytes:l->challenge length:8]];
            [WaveHelper secureReplace:&_username    withObject:[NSString stringWithCString:(char*)&l->name length:userLength]];
            break;
        case leapAuthCodeResponse:  //handle response
            if (frameLength-16 < 24) return NO;
            [WaveHelper secureReplace:&_response   withObject:[NSData dataWithBytes:l->challenge length:24]];
            break; 
        default:
            break;
    }
    
    return YES;
}

- (leapAuthCode)leapCode {
    return _leapCode;
}
- (NSString*)username {
    return _username;
}
- (NSData*)challenge {
    return _challenge;
}
- (NSData*)response {
    return _response;
}

@end
