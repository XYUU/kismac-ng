/*
        
        File:			WayPoint.m
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

#import "WayPoint.h"

@implementation WayPoint

- (void)awakeFromNib {
    [[self window] setDelegate:self];
}

- (void)setCallbackStruct:(waypointdlg*) wpd {
    aWPD=wpd;
    aWPD->canceled = YES;
    [aLat  setFloatValue: ((aWPD->w._lat >= 0) ? aWPD->w._lat : -aWPD->w._lat) ];
    [aLong setFloatValue: ((aWPD->w._long>= 0) ? aWPD->w._long: -aWPD->w._long)];
    
    if (aWPD->w._lat>=0)  [aNS setStringValue:@"N"];
    else  [aNS setStringValue:@"S"];
    
    if (aWPD->w._long>=0) [aEW setStringValue:@"E"];
    else  [aEW setStringValue:@"W"];
}

- (IBAction)NSStepClicked:(id)sender {
    if ([[aNS stringValue] isEqualToString:@"N"]) [aNS setStringValue:@"S"];
    else [aNS setStringValue:@"N"];
}

- (IBAction)EWStepClicked:(id)sender {
    if ([[aEW stringValue] isEqualToString:@"E"]) [aEW setStringValue:@"W"];
    else [aEW setStringValue:@"E"];
}

- (IBAction)OKClicked:(id)sender {
    aWPD->canceled = NO;
    aWPD->w._lat = [aLat  floatValue] * ([[aNS stringValue] isEqualToString:@"N"] ? 1.0 : -1.0);
    aWPD->w._long = [aLong  floatValue] * ([[aEW stringValue] isEqualToString:@"E"] ? 1.0 : -1.0);
    [self close];
}

- (IBAction)CancelClicked:(id)sender {
    [self close];
}

- (void)windowWillClose:(NSNotification *)aNotification {
    aWPD->done = YES;
}

@end
