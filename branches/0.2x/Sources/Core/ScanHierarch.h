/*
        
        File:			ScanHierarch.h
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

#import <Foundation/Foundation.h>
#import "WaveNet.h"
#import "WaveContainer.h"

// this the responsible structure for the tree view. very ugly and dirty
@interface ScanHierarch : NSObject {
    WaveContainer *_container;
    NSString *aNameString;
    NSString *aIdentKey;
    int aType;
    ScanHierarch *parent;
    NSMutableArray *children;
}

+ (ScanHierarch *) rootItem:(WaveContainer*)container index:(int)idx;
+ (void) updateTree;
+ (void) clearAllItems;

+ (void) setContainer:(WaveContainer*)container;

- (NSComparisonResult)compare:(ScanHierarch *)aHier;
- (NSComparisonResult)caseInsensitiveCompare:(ScanHierarch *)aHier;
- (int)numberOfChildren;			// Returns -1 for leaf nodes
- (ScanHierarch *)childAtIndex:(int)n;		// Invalid to call on leaf nodes
- (int)type;
- (NSString *)nameString;
- (NSString *)identKey;
@end
