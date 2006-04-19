/*
        
        File:			PrefsGPS.m
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

#import "PrefsGPS.h"
//#import <FourCoordinates/FourCoordinates.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>

@implementation PrefsGPS

-(NSString*) getRegistryString:(io_object_t) sObj name:(char *)propName {
    static char resultStr[256];
    CFTypeRef nameCFstring;

    resultStr[0] = 0;
    nameCFstring = IORegistryEntryCreateCFProperty (
        sObj, CFStringCreateWithCString (
            kCFAllocatorDefault, propName, kCFStringEncodingASCII),
        kCFAllocatorDefault, 0);
    if (nameCFstring)
    {
        CFStringGetCString (
            nameCFstring, resultStr, sizeof (resultStr),
            kCFStringEncodingASCII);
        CFRelease (nameCFstring);
    }
    return [NSString stringWithCString:resultStr];
}

- (void)updateRestrictions {
    switch ([aGPSSel indexOfSelectedItem]) {
        case 0:
            [_gpsdHost setEnabled:NO];
            [_gpsdPort setEnabled:NO];
            [_noFix setEnabled:NO];
            [_traceOp setEnabled:NO];
            [_tripmateMode setEnabled:NO];
            break;
        case 1:
            [_gpsdHost setEnabled:YES];
            [_gpsdPort setEnabled:YES];
            [_noFix setEnabled:YES];
            [_traceOp setEnabled:YES];
            [_tripmateMode setEnabled:YES];
            break;
        default:
            [_gpsdHost setEnabled:NO];
            [_gpsdPort setEnabled:NO];
            [_noFix setEnabled:YES];
            [_traceOp setEnabled:YES];
            [_tripmateMode setEnabled:YES];
            break;
    }
}
- (void)updateUI {
    unsigned int i;
    kern_return_t kernResult;
    mach_port_t masterPort;
    CFMutableDictionaryRef classesToMatch;
    io_iterator_t serialIterator;
    io_object_t sdev;
    NSMutableArray *a = [NSMutableArray array];
    bool found;
    
    [aGPSSel removeAllItems];
    [_tripmateMode setState: [[controller objectForKey:@"GPSTripmate"] boolValue] ? NSOnState : NSOffState];
    
    kernResult = IOMasterPort(0, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        goto err; // REV/FIX: throw.
    }
    classesToMatch = IOServiceMatching (kIOSerialBSDServiceValue);
    if (0 == classesToMatch)
    {
        goto err; // REV/FIX: throw.
    }
    CFDictionarySetValue (
        classesToMatch,
        CFSTR (kIOSerialBSDTypeKey),
        CFSTR (kIOSerialBSDRS232Type));
    kernResult = IOServiceGetMatchingServices (
        masterPort, classesToMatch, &serialIterator);
    if (KERN_SUCCESS != kernResult)
    {
        goto err; // REV/FIX: throw.
    }
    while ((sdev = IOIteratorNext (serialIterator)))
    {
        NSString *tty = [self getRegistryString: sdev name:kIODialinDeviceKey];
        [a addObject: tty];
    }
    IOObjectRelease (serialIterator);
    
err:
    [_noFix selectItemAtIndex:[[controller objectForKey:@"GPSNoFix"] intValue]];
    [_traceOp selectItemAtIndex:[[controller objectForKey:@"GPSTrace"] intValue]];
    [_gpsdPort setIntValue:[[controller objectForKey:@"GPSDaemonPort"] intValue]];
    [_gpsdHost setStringValue:[controller objectForKey:@"GPSDaemonHost"]];

    found = NO;
    [aGPSSel addItemWithTitle: NSLocalizedString(@"<do not use GPS integration>", "menu item for GPS prefs")];
    [aGPSSel addItemWithTitle: NSLocalizedString(@"<use GPSd to get coordinates>", "menu item for GPS prefs")];
    
    if ([a count] > 0) [[aGPSSel menu] addItem:[NSMenuItem separatorItem]];
    
    if ([[controller objectForKey:@"GPSDevice"] isEqualToString:@""]) {
        [aGPSSel selectItemAtIndex:0];
        found = YES;
    }
    
    if ([[controller objectForKey:@"GPSDevice"] isEqualToString:@"GPSd"]) {
        [aGPSSel selectItemAtIndex:1];
        found = YES;
    }
    
    for (i=0;i<[a count];i++) {
        [aGPSSel addItemWithTitle:[a objectAtIndex:i]];
        if ([[controller objectForKey:@"GPSDevice"] isEqualToString:[a objectAtIndex:i]]) {
            [aGPSSel selectItemAtIndex:(i+3)];
            found = YES;
        }
    }
    
    if (!found) {
        [aGPSSel addItemWithTitle:[controller objectForKey:@"GPSDevice"]];
        [aGPSSel selectItemAtIndex:[a count]+1];
    }
    
    [aGPSSel setEnabled:YES];
    [self updateRestrictions];
}

-(BOOL)updateDictionary {
    
    if ((![aGPSSel isEnabled]) || ([aGPSSel indexOfSelectedItem]==0)) {
        [controller setObject:@"" forKey:@"GPSDevice"];
    } else if ([[aGPSSel titleOfSelectedItem] isEqualToString: NSLocalizedString(@"<use GPSd to get coordinates>", "menu item for GPS prefs")]) {
        [controller setObject:@"GPSd" forKey:@"GPSDevice"];
    } else {
        [controller setObject:[aGPSSel titleOfSelectedItem] forKey:@"GPSDevice"];
    }
    
    [_gpsdPort validateEditing];
    [_gpsdHost validateEditing];
    
    [controller setObject:[NSNumber numberWithInt:[_noFix indexOfSelectedItem]] forKey:@"GPSNoFix"];
    [controller setObject:[NSNumber numberWithInt:[_traceOp indexOfSelectedItem]] forKey:@"GPSTrace"];
    [controller setObject:[NSNumber numberWithBool:[_tripmateMode state]==NSOnState] forKey:@"GPSTripmate"];
    [controller setObject:[NSNumber numberWithInt:[_gpsdPort intValue]] forKey:@"GPSDaemonPort"];
    [controller setObject:[[_gpsdHost stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"GPSDaemonHost"];
    
    [self updateRestrictions];

    return YES;
}

-(IBAction)setValueForSender:(id)sender {
    if(sender == aGPSSel) {
        [self updateDictionary];
    } else if (sender == _noFix) {
        [controller setObject:[NSNumber numberWithInt:[_noFix indexOfSelectedItem]] forKey:@"GPSNoFix"];
    } else if (sender == _traceOp) {
        [controller setObject:[NSNumber numberWithInt:[_traceOp indexOfSelectedItem]] forKey:@"GPSTrace"];
    } else if (sender == _tripmateMode) {
        [controller setObject:[NSNumber numberWithBool:[_tripmateMode state]==NSOnState] forKey:@"GPSTripmate"];
    } else if (sender == _gpsdPort) {
        [controller setObject:[NSNumber numberWithInt:[_gpsdPort intValue]] forKey:@"GPSDaemonPort"];
    } else if (sender == _gpsdHost) {
        [controller setObject:[[_gpsdHost stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"GPSDaemonHost"];
    } else {
        NSLog(@"Error: Invalid sender(%@) in setValueForSender:",sender);
    }
}

@end
