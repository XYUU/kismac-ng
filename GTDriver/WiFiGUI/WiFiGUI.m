/*
        
        File:			WiFiGUI.m
        Program:		WiFiGUI
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		GTDriver is a free driver for PrismGT based cards under OS X.
                
        This file is part of GTDriver.

    GTDriver is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    GTDriver is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with GTDriver; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import "WiFiGUI.h"
#import "WiFiPasswordEncrypt.h"

@implementation WiFiGUI

- (void)awakeFromNib {    
    _statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
    [_statusItem setHighlightMode:YES];
    [_statusItem setMenu: _menu];
    [_statusItem setEnabled:YES];
    
    [_encryptionType removeAllItems];
    [_encryptionType addItemsWithTitles:[WiFiPasswordEncrypt encryptionTechnics]];
    
    _formatter = [[HexNumberFormatter alloc] init];    
    [_formatter setCallback:@selector(updateValidPassword:) forObject:self];
    [_wepKeyBox setFormatter:_formatter];
    _activeNet = [[NSString stringWithString:@""] retain];

    _lastNet = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Network"];
    if (!_lastNet) _lastNet = Nil;
    [_lastNet retain];

    _mainTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timer:) userInfo:nil repeats:YES] retain];
    [_mainTimer fire];
}

#pragma mark -

- (NSString*)dataToHex:(NSData*)data {
    const UInt8 *b;
    int l, t;
    NSMutableString *s = [NSMutableString stringWithString:@"0x"];
    b = (UInt8*)[data bytes];
    
    for (l = 0; l < [data length]; l++) {
        t = b[l];
        [s appendFormat:@"%.2x", t];
    }
    
    return s;
}

- (NSData*)hexToData:(NSString*)hex {
    NSMutableData *d;
    int tmp, i;
    UInt8 *x;
    d = [NSMutableData dataWithCapacity:[hex length]/2];
    [d setLength:[hex length]/2];
    x = [d mutableBytes];
    
    i = 0;
    while([hex length]) {
        sscanf([[hex substringToIndex:2] cString], "%x", &tmp);
        x[i++] = tmp;
        hex = [hex substringFromIndex:2];
    }
    return d;
}

- (void)joinNetworkWithSSID:(NSString*)SSID andPassword:(NSData*)password {
    [_di setSSID:SSID];
    [_di setWEPKey:password];
    
    [_activeNet release];
    _activeNet = [SSID retain];
    
    [[NSUserDefaults standardUserDefaults] setObject:_activeNet forKey:@"Last Network"];
    
    [_lastNet release];
    _lastNet = [SSID retain];
}

- (void)joinNetworkWithSSID:(NSString*)SSID {
    [self joinNetworkWithSSID:SSID andPassword:[NSData data]];
}

#pragma mark -

- (void)timer:(NSTimer *)timer {
    [self updateMenu];
    if ([_joinWindow isVisible]) [self updateValidPassword:self];
}

#define max(a, b) ((a > b) ? b : a)

- (void)updateMenu {
    NSMenuItem *item;
    int linkSpeed;
    BOOL driverPresent = NO;
    NSString *state = @"No Card";
    
    if ([WiFiDriverInterface isServiceAvailable:"GTDriver"]) {
        if (!_di) {
            _di = [[WiFiDriverInterface alloc] initWithDriverNamed:@"GTDriver"];
        }
        if (_di) {
            switch ([_di getConnectionState]) {
                case stateIntializing:
                    state = @"Initializing";
                    break;
                case stateCardEjected:
                    state = @"Card Ejected";
                    break;
                case stateSleeping:
                    state = @"Sleeping";
                    break;
                case stateDisabled:
                    state = @"Disabled";
                    break;
                case stateDisconnected:
                    driverPresent = YES;
                    state = @"Disconnected";
                    break;
                case stateDeauthenticated:
                    driverPresent = YES;
                    state = @"Deauthenticated";
                    break;
                case stateDisassociated:
                    driverPresent = YES;
                    state = @"Disassociated";
                    break;
                case stateAuthenicated:
                    driverPresent = YES;
                    state = @"Authenticated";
                    break;
                case stateAssociated:
                    driverPresent = YES;
                    state = @"Associated";
                    break;
            }
            if (driverPresent) {
                linkSpeed = [_di linkSpeed];
                [_statusItem setImage:[NSImage imageNamed:[NSString stringWithFormat:@"Status%d.tif", max((linkSpeed / 10), 4)]]];
            } else {
                [_statusItem setImage:[NSImage imageNamed:@"StatusDead.tif"]];
            }
        } else {
            [_statusItem setImage:nil];
            state = @"No Driver";
        }
    } else {
        [_statusItem setImage:nil];
        [_activeNet release];
        _activeNet = [[NSString stringWithString:@""] retain];
        [_di release];
        _di = Nil;
    }
    
    int  i = 2;
    while (![[[_menu itemAtIndex:i] title] isEqualToString:@"Open Network Preferences..."]) {
        [_menu removeItemAtIndex:i];
    };
    
    if (!driverPresent) {
        [_networkList release];
        _networkList = Nil;
    } else {
        [_menu insertItem:[NSMenuItem separatorItem] atIndex:2];
        [[_menu insertItemWithTitle:@"Other..." action:@selector(joinOtherNetwork:) keyEquivalent:@"" atIndex:2] setTarget:self];
        
        [_networkList release];
        _networkList = [[_di getNetworks] retain];
        [_ssidList removeAllItems];
        if ([_networkList count]) {
            NSArray* keys;
            NSMenuItem *m;
            BOOL ibss = NO;
            
            keys = [[_networkList allKeys] sortedArrayUsingSelector:@selector(compare:)];
            for (i = [keys count]; i > 0 ; i--) {
                if(![[[_networkList objectForKey:[keys objectAtIndex:i - 1]] objectForKey:@"IBSS"] boolValue]) continue;
                
                ibss = YES;
                m = (NSMenuItem*)[_menu insertItemWithTitle:[keys objectAtIndex:i - 1] action:@selector(joinNetwork:) keyEquivalent:@"" atIndex:2];
                [m setTarget:self];
                if ([[[_networkList objectForKey:[keys objectAtIndex:i - 1]] objectForKey:@"Active"] boolValue]) {
                    [m setState:NSOnState];
                    if (![[keys objectAtIndex:i - 1] isEqualToString:_activeNet]) [self performSelectorOnMainThread:@selector(joinNetwork:) withObject:m waitUntilDone:NO];
                }
                [_ssidList insertItemWithObjectValue:[keys objectAtIndex:i - 1] atIndex:0];
            }
            if (ibss) {
                [[_menu insertItemWithTitle:@"Computer-to-Computer Networks" action:nil keyEquivalent:@"" atIndex:2] setTarget:self];
            }
            
            for (i = [keys count]; i > 0 ; i--) {
                if([[[_networkList objectForKey:[keys objectAtIndex:i - 1]] objectForKey:@"IBSS"] boolValue]) continue;
                
                m = (NSMenuItem*)[_menu insertItemWithTitle:[keys objectAtIndex:i - 1] action:@selector(joinNetwork:) keyEquivalent:@"" atIndex:2];
                [m setTarget:self];
                if ([[[_networkList objectForKey:[keys objectAtIndex:i - 1]] objectForKey:@"Active"] boolValue]) {
                    [m setState:NSOnState];
                    if (![[keys objectAtIndex:i - 1] isEqualToString:_activeNet]) [self performSelectorOnMainThread:@selector(joinNetwork:) withObject:m waitUntilDone:NO];
                }
                [_ssidList insertItemWithObjectValue:[keys objectAtIndex:i - 1] atIndex:0];
            }
        } else {
            item = [[NSMenuItem alloc] init];
            [item setTitle:@"No Networks found"];
            [_menu insertItem:item atIndex:2];
            [item release];
        }
    }
    
    [[_menu itemAtIndex:0] setTitle:[NSString stringWithFormat:@"Wireless: %@", state]];

    if ([_activeNet length] == 0 && [_networkList count] != 0 && [_lastNet length] != 0) {
        if ([_networkList objectForKey:_lastNet]) [self joinNetwork:[_menu itemWithTitle:_lastNet]];
    }
}


- (IBAction)updateEncryptionType:(id)sender {
    NSRect frame;
    frame = [_joinWindow frame];
    if ([_encryptionType indexOfSelectedItem] == 0 && ![_passwordView isHidden]) {
        frame.size.height -= [_passwordView frame].size.height;
        frame.origin.y    += [_passwordView frame].size.height;
        [_passwordView  setHidden:YES];
        [_passwordLabel setHidden:YES];
        [_joinWindow setFrame:frame display:YES animate:[_joinWindow isVisible]];
    } else if ([_encryptionType indexOfSelectedItem] != 0 && [_passwordView isHidden]) {
        frame.size.height += [_passwordView frame].size.height;
        frame.origin.y    -= [_passwordView frame].size.height;
        [_passwordView  setHidden:NO];
        [_passwordLabel setHidden:NO];
        [_joinWindow setFrame:frame display:YES animate:[_joinWindow isVisible]];
    }
    
    switch ([_encryptionType indexOfSelectedItem]) {
        case 0:
            [_passwordBox   setHidden:YES];
            [_wepKeyBox     setHidden:YES];
            break;
        case 3:
        case 4:
            [_passwordBox   setHidden:YES];
            [_wepKeyBox     setHidden:NO];
            break;
        default:
            [_passwordBox   setHidden:NO];
            [_wepKeyBox     setHidden:YES];
    }
    
    [self updateValidPassword:sender];
}

- (IBAction)updateValidPassword:(id)sender {
    BOOL enable;
    
    switch ([_encryptionType indexOfSelectedItem]) {
        case 0:
            enable = YES;
            break;
        case 3:
            [_wepKeyBox validateEditing];
            enable = [WiFiPasswordEncrypt validPassword:[_wepKeyBox stringValue] forType:[_encryptionType indexOfSelectedItem]];
            break;
        default:
            [_passwordBox validateEditing];
            enable = [WiFiPasswordEncrypt validPassword:[_passwordBox stringValue] forType:[_encryptionType indexOfSelectedItem]];
    }
    [_joinButton setEnabled:enable];
}

#pragma mark -

- (IBAction)joinNetwork:(id)sender {
    NSString *password;
    if ([sender state] == NSOnState && [_activeNet length] != 0) return;
   
    if (![[[_networkList objectForKey:[sender title]] objectForKey:@"WEP"] boolValue]) {
        [self joinNetworkWithSSID:[sender title]];
        return;
    }
    
    password = [WiFiPasswordEncrypt getPasswordForAccount:[sender title]];
    if (password) {
        NSData *pwd;
        if ([[password substringToIndex:2] isEqualToString:@"0x"])  pwd = [self hexToData:[password substringFromIndex:2]];
        else pwd = [WiFiPasswordEncrypt hashPassword:password forType:1];

        [self joinNetworkWithSSID:[sender title] andPassword:pwd];        
    } else {
        [_ssidList setStringValue:[sender title]];
        [_encryptionType selectItemAtIndex:1];
        [self joinOtherNetwork:sender];
    }
}

- (IBAction)joinOtherNetwork:(id)sender {
    [self updateEncryptionType:sender];
    [self updateValidPassword:sender];

    [_joinWindow orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];
    [_joinWindow makeKeyWindow];
    [self updateValidPassword:sender];
}

- (IBAction)joinNamedNetwork:(id)sender {
    NSData *password;
    NSAssert(_di, @"No driver present!");    
    
    password = [WiFiPasswordEncrypt hashPassword:[_encryptionType indexOfSelectedItem] == 3 ? [_wepKeyBox stringValue] : [_passwordBox stringValue] forType:[_encryptionType indexOfSelectedItem]];
    [WiFiPasswordEncrypt storePassword:[self dataToHex:password] forAccount:[_ssidList stringValue]];
    
    [self joinNetworkWithSSID:[_ssidList stringValue] andPassword:password];        
    [_joinWindow orderBack:self];
    [_passwordBox setStringValue:@""];
}

- (IBAction)openPrefs:(id)sender {
    [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObject:@"/System/Library/PreferencePanes/Network.prefPane"]]; 
}

#pragma mark -

- (void)dealloc {
    [_mainTimer invalidate];
    [_mainTimer release];
    [_networkList release];
    [_statusItem release];
    [_di release];
    [_formatter release];
    [_activeNet release];
    [_lastNet release];
    
    [super dealloc];
}
@end
