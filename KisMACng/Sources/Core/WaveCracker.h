/*
        
        File:			WaveCracker.h
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
#import "RC4.h"
#import "WaveNet.h"
#import "ImportController.h"
#import "Apple80211.h"

#include <sys/sysctl.h>

struct sScore {
    unsigned int score;
    unsigned char index;
};


typedef unsigned long int UNS_32_BITS;
typedef void (*keyfunction)(unsigned char *);


@interface WaveCracker : NSObject {
    unsigned char aCurGuess[16];	//this is our key guess. iv+password
    unsigned char aData[2300];		//we keep one package in cache
    unsigned int  aLength;		//length of the package
    bool aIsInit;			//is Packet initialized?
    int _chars;
    NSArray* _filenames;
    WaveNet* _net;
    unsigned int _breath;
    int _keywidth;
    
    struct sScore aMaster[256];		//also for caching
    NSMutableString *aKey;		//the key (if found)
    ImportController *_im;
}

-(void) crackWithKeyByteLength:(unsigned int)a net:(WaveNet*)aNet breath:(unsigned int)b import:(ImportController*)im;	
-(void) crackWithWordlist:(NSArray*)filenames useCipher:(unsigned int)a net:(WaveNet*)aNet import:(ImportController*)i;

                                                                                //try to crack the key of a 8*a bit network based on weak keys
- (NSString*)key;								//returns the cracked key

- (int)doWordlistAttack40Apple:(WaveNet *)aNet withWordlist:(NSString*)filename;
- (int)doWordlistAttack104Apple:(WaveNet *)aNet withWordlist:(NSString*)filename;
- (int)doWordlistAttack104MD5:(WaveNet *)aNet withWordlist:(NSString*)filename;
@end
