/*
        
        File:			WaveNetWeakWEPCrack.m
        Program:		KisMAC
	Author:			Michael Rossberg
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

#import "WaveNetWEPWeakCrack.h"


@implementation WaveNet(WEPWeakCrackExtension)

- (void)crackWEPWeakforKeyIDAndLen:(NSNumber*)keyidAndLen {
    char option[4];
    int temp;
    
    temp = [keyidAndLen intValue];
    memcpy(&option, &temp, 4);
    
    
}

@end
