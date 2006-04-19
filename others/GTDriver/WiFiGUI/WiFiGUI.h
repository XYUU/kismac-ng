/*
        
        File:			WiFiGUI.h
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

#import <Foundation/Foundation.h>
#import "WiFiDriverInterface.h"
#import "HexNumberFormatter.h"

@interface WiFiGUI : NSObject {
    IBOutlet NSMenu         *_menu;
    IBOutlet NSWindow       *_joinWindow;
    IBOutlet NSButton       *_joinButton;
    IBOutlet NSComboBox     *_ssidList;
    IBOutlet NSPopUpButton  *_encryptionType;
    IBOutlet NSTextField    *_passwordBox;
    IBOutlet NSTextField    *_wepKeyBox;
    IBOutlet NSTextField    *_passwordLabel;
    IBOutlet NSBox          *_passwordView;
    
    HexNumberFormatter  *_formatter;
    NSStatusItem        *_statusItem;
    NSTimer             *_mainTimer;
    WiFiDriverInterface *_di;
    NSString            *_activeNet, *_lastNet;
    
    NSDictionary        *_networkList;
}

- (void)timer:(NSTimer *)timer;
- (void)updateMenu;
- (IBAction)updateEncryptionType:(id)sender;
- (IBAction)updateValidPassword:(id)sender;
- (IBAction)joinNetwork:(id)sender;
- (IBAction)joinNamedNetwork:(id)sender;
- (IBAction)joinOtherNetwork:(id)sender;
- (IBAction)openPrefs:(id)sender;
@end
