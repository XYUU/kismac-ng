/*
        
        File:			ScanControllerMenus.m
        Program:		KisMAC
	Author:			Michael Roßberg
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

#import <BIGeneric/ColoredRowTableView.h>
#import "ScanController.h"
#import "ScanControllerPrivate.h"
#import "ScanControllerScriptable.h"
#import "KisMACNotifications.h"
#import "../WindowControllers/DownloadMapController.h"
#import "DecryptController.h"
#import "HTTPStream.h"
#import "../Crypto/WPA.h"
#import "TrafficController.h"
#import "../WaveDrivers/WaveDriver.h"
#import "MapView.h"
#import "MapViewAreaView.h"

@implementation ScanController(MenuExtension)

#pragma mark -
#pragma mark KISMAC MENU
#pragma mark -

- (IBAction)showPrefs:(id)sender {
    if(!prefsWindow) {
        if(![NSBundle loadNibNamed:@"Preferences" owner:self]) {
            NSLog(@"Preferences.nib failed to load!");
            return;
        }
    } else
        [prefsController refreshUI:self];
    
    if(![[NSUserDefaults standardUserDefaults] objectForKey:@"NSWindow Frame prefsWindow"])
        [prefsWindow center];

    [prefsWindow makeKeyAndOrderFront:nil];
}

#pragma mark -
#pragma mark FILE MENU
#pragma mark -

- (IBAction)importImage:(id)sender {
    aOP=[NSOpenPanel openPanel];
    [aOP setAllowsMultipleSelection:NO];
    [aOP setCanChooseFiles:YES];
    [aOP setCanChooseDirectories:NO];
    if ([aOP runModalForTypes:[NSImage imageFileTypes]]==NSOKButton) {
        [self clearAreaMap];
        [self showBusy:@selector(performImportMap:) withArg:[[aOP filenames] objectAtIndex:0]];
    }
}
- (void)performImportMap:(id)filename {
    NSImage *x;
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Importing %@...", "Status for busy dialog"), filename]];  
  
    x=[[NSImage alloc] initWithContentsOfFile:filename];
    [_mappingView setMap:x];
    [x release];
    [self showMap];
}

- (IBAction)importMapFromServer:(id)sender {
    DownloadMapController* dmc = [[DownloadMapController alloc] initWithWindowNibName:@"DownloadMap"];
    
    [[dmc window] setFrameUsingName:@"aKisMAC_DownloadMap"];
    [[dmc window] setFrameAutosaveName:@"aKisMAC_DownloadMap"];
    
    [dmc setCoordinates:[[WaveHelper gpsController] currentPoint]];
    [dmc showWindow:self];
    [[dmc window] makeKeyAndOrderFront:self];
}

- (IBAction)importFile:(id)sender {
    aOP=[NSOpenPanel openPanel];
    [aOP setAllowsMultipleSelection:NO];
    [aOP setCanChooseFiles:YES];
    [aOP setCanChooseDirectories:NO];
    if ([aOP runModalForTypes:[NSArray arrayWithObject:@"kismac"]]==NSOKButton) {
        [self stopActiveAttacks];
        [self stopScan];

        [self showBusy:@selector(performImportFile:) withArg:[aOP filename]];

        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    }
}
- (void)performImportFile:(NSString*)filename {
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Importing %@...", "Status for busy dialog"), filename]];  

    _refreshGUI = NO;
    [scanner importFromFile:filename];
    _refreshGUI = YES;
 
    [self updateNetworkTable:self complete:YES];
    [self refreshScanHierarch];
    [_window setDocumentEdited:YES];
}

- (IBAction)importNetstumbler:(id)sender {
    aOP=[NSOpenPanel openPanel];
    [aOP setAllowsMultipleSelection:NO];
    [aOP setCanChooseFiles:YES];
    [aOP setCanChooseDirectories:NO];
    if ([aOP runModalForTypes:[NSArray arrayWithObjects:@"txt", @"ns1", nil]]==NSOKButton) {
        [self stopActiveAttacks];
        [self stopScan];

        [self showBusy:@selector(performImportNetstumbler:) withArg:[aOP filename]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACViewItemChanged object:self];
    }
}
- (void)performImportNetstumbler:(NSString*)filename {
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Importing %@...", "Status for busy dialog"), filename]];  
    
    _refreshGUI = NO;
    [scanner importFromNetstumbler:filename];
    _refreshGUI = YES;

    [self updateNetworkTable:self complete:YES];
    [self refreshScanHierarch];
    [_window setDocumentEdited:YES];
}

#pragma mark -

- (IBAction)exportNS:(id)sender {
    NSSavePanel *aSP;
    aSP=[NSSavePanel savePanel];
    [aSP setRequiredFileType:@"ns1"];
    [aSP setCanSelectHiddenExtension:YES];
    [aSP setTreatsFilePackagesAsDirectories:NO];
    if ([aSP runModal]==NSFileHandlingPanelOKButton) {
        [self showBusy:@selector(performExportNS:) withArg:[aSP filename]];
        if (_asyncFailure) [self showExportFailureDialog];
    }
}
- (void)performExportNS:(id)filename {
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Exporting to %@...", "Status for busy dialog"), filename]];  

    if (![scanner exportNSToFile:filename]) _asyncFailure = YES;
    else _asyncFailure = NO;
}

- (IBAction)exportWarD:(id)sender {
    NSSavePanel *aSP;
    
    aSP=[NSSavePanel savePanel];
    [aSP setRequiredFileType:@"txt"];
    [aSP setCanSelectHiddenExtension:YES];
    [aSP setTreatsFilePackagesAsDirectories:NO];
    if ([aSP runModal]==NSFileHandlingPanelOKButton) {
        [self showBusy:@selector(performExportWarD:) withArg:[aSP filename]];
        if (_asyncFailure) [self showExportFailureDialog];
    }
}
- (void)performExportWarD:(id)filename {
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Exporting to %@...", "Status for busy dialog"), filename]];  

    _asyncFailure = ! [[scanner webServiceData] writeToFile:[filename stringByExpandingTildeInPath] atomically:YES];
}

- (IBAction)exportToServer:(id)sender {
    NSUserDefaults *defs;

    defs = [NSUserDefaults standardUserDefaults];
    if (![defs boolForKey:@"useWebService"]) {
        NSBeginCriticalAlertSheet(
        NSLocalizedString(@"Export failed", "Export failure dialog title"),
        OK, NULL, NULL, _window, self, NULL, NULL, NULL, 
        NSLocalizedString(@"Server Export disabled", "LONG Export failure dialog text. Enable it in preferences")
        );
        return;
    }

    if ([[defs stringForKey:@"webServiceAccount"] length] == 0) {
        NSBeginCriticalAlertSheet(
        NSLocalizedString(@"Export failed", "Export failure dialog title"),
        OK, NULL, NULL, _window, self, NULL, NULL, NULL, 
        NSLocalizedString(@"No account name given. Enter it in the preferences.", "For export Server.")
        );
        return;
    }
    
    [self showBusy:@selector(performExportToServer:) withArg:[NSNumber numberWithBool:YES]];
}

- (void)performExportToServer:(id)reportErrors {
    NSUserDefaults *defs;
    NSString *account, *password, *data, *errorStr;
    NSURL *url;
    HTTPStream *stream;
    
    [_importController setTitle:NSLocalizedString(@"Exporting to .kismac Server...", "Status for busy dialog")];  
    defs = [NSUserDefaults standardUserDefaults];

    if (![defs boolForKey:@"useWebService"]) {
        NSLog(@"Webserver export has been disabled!");
        return;
    }

    account = [defs stringForKey:@"webServiceAccount"];
    if (!account) {
        NSLog(@"Something is wrong with your webService preferences!");
        return;
    }

    password = [WaveHelper getPasswordForAccount:account];
    if (!password) {
        NSLog(@"Looks like KisMAC does not have access to it's WebService password. Cancel export.");
        return;
    }

    data = [scanner webServiceData];
    
    // Create a new url based upon the user entered string
    url = [NSURL URLWithString: @"http://binaervarianz.de/projekte/programmieren/kismac/.uploadnets.php"];
    
    stream = [[HTTPStream alloc] initWithURL:url andPostVariables:[NSDictionary dictionaryWithObjectsAndKeys:
        account,    @"user",
        password,   @"pass",
        data,       @"file",
        nil]
      reportErrors:[reportErrors boolValue]];
    
    if ([reportErrors boolValue] && [stream errorCode]!=201) {
        switch ([stream errorCode]) {
        case -1:
            errorStr = NSLocalizedString(@"Could not connect to Internet Server. Please check your internet connection and see if you can connect to http://binaervarianz.de.", "For export Server.");
            break;
        case 500:
            errorStr = NSLocalizedString(@"The Internet server reported an Internal Error. Please export your data and send it to us for debugging.", "For export Server.");
            break;
        case 401:
            errorStr = NSLocalizedString(@"Access denied. Please check your account and password settings.", "For export Server.");
            break;
        case 201:
            errorStr = @"";
            break;
        default:
            errorStr = NSLocalizedString(@"The Server answerd with an unknown error code! Please check for a new KisMAC version.", "For export Server.");
        }
        
        NSBeginCriticalAlertSheet(
        NSLocalizedString(@"Export failed", "Export failure dialog title"),
        OK, NULL, NULL, _window, self, NULL, NULL, NULL, 
        errorStr
        );
       
    }
    [stream release];
}

- (IBAction)exportMacstumbler:(id)sender {
    NSSavePanel *aSP;
    
    aSP=[NSSavePanel savePanel];
    [aSP setRequiredFileType:@"txt"];
    [aSP setCanSelectHiddenExtension:YES];
    [aSP setTreatsFilePackagesAsDirectories:NO];
    if ([aSP runModal]==NSFileHandlingPanelOKButton) {
        [self showBusy:@selector(performExportMacStumbler:) withArg:[aSP filename]];
        if (_asyncFailure) [self showExportFailureDialog];
    }
}
- (void)performExportMacStumbler:(id)filename {
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Exporting to %@...", "Status for busy dialog"), filename]];  

    if (![scanner exportMacStumblerToFile:filename]) _asyncFailure = YES;
    else _asyncFailure = NO;
}

- (IBAction)exportPDF:(id)sender {
    NSSavePanel *aSP;
    
    aSP=[NSSavePanel savePanel];
    [aSP setRequiredFileType:@"pdf"];
    [aSP setCanSelectHiddenExtension:YES];
    [aSP setTreatsFilePackagesAsDirectories:NO];
    if ([aSP runModal]==NSFileHandlingPanelOKButton) {
        [self showBusy:@selector(performExportPDF:) withArg:[aSP filename]];
        if (_asyncFailure) [self showExportFailureDialog];
    }
}
- (void)performExportPDF:(id)filename {
    NSData *data;
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Exporting to %@...", "Status for busy dialog"), filename]];  
    
    NS_DURING
        //TODO
        data = [_mappingView pdfData];
        [data writeToFile:[filename stringByExpandingTildeInPath] atomically:NO];
        _asyncFailure = NO;
    NS_HANDLER
        _asyncFailure = YES;
    NS_ENDHANDLER
}

- (IBAction)exportJPEG:(id)sender {
    NSSavePanel *aSP;
    
    aSP=[NSSavePanel savePanel];
    [aSP setRequiredFileType:@"jpg"];
    [aSP setCanSelectHiddenExtension:YES];
    [aSP setTreatsFilePackagesAsDirectories:NO];
    if ([aSP runModal]==NSFileHandlingPanelOKButton) {
        [self showBusy:@selector(performExportJPEG:) withArg:[aSP filename]];
        if (_asyncFailure) [self showExportFailureDialog];
    }
}
- (void)performExportJPEG:(id)filename {
    NSData *data;
    NSImage *img;
    [_importController setTitle:[NSString stringWithFormat:NSLocalizedString(@"Exporting to %@...", "Status for busy dialog"), filename]];  
    
    NS_DURING
        img  = [[NSImage alloc] initWithData:[_mappingView pdfData]];
        data = [img TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0];
        data = [[NSBitmapImageRep imageRepWithData:data] representationUsingType:NSJPEGFileType properties:nil];
            
        [data writeToFile:[filename stringByExpandingTildeInPath] atomically:NO];
        [img release];
        
        _asyncFailure = NO;
    NS_HANDLER
        _asyncFailure = YES;
    NS_ENDHANDLER
}
    
#pragma mark -

- (IBAction)decryptPCAPFile:(id)sender {
    DecryptController* d;
    
    d = [[DecryptController alloc] initWithWindowNibName:@"DecryptDialog"];
    [d showWindow:sender];
}

#pragma mark -
#pragma mark CHANNEL MENU
#pragma mark -

- (IBAction)selChannel:(id)sender {
    WaveDriver *wd;
    NSMutableDictionary *md;
    int y;
    int newChannel = [[[sender title] substringFromIndex:8] intValue];
    
    wd = [WaveHelper driverWithName:_whichDriver];
    if (!wd) {
        NSLog(@"Error: invalid driver selected");
        return;
    }
    
    md = [[wd configuration] mutableCopy];
    for(y=1; y<15; y++)
        [md setObject:[NSNumber numberWithInt:(y==newChannel) ? 1 : 0] forKey:[NSString stringWithFormat:@"useChannel%.2i",y]];
  
    [wd setConfiguration: md];
    [md release];

    [self updateChannelMenu];
}

- (IBAction)selChannelRange:(id)sender {
    WaveDriver *wd;
    NSMutableDictionary *md;
    int y;
    
    wd = [WaveHelper driverWithName:_whichDriver];
    if (!wd) {
        NSLog(@"Error: invalid driver selected");
        return;
    }
    
    md = [[wd configuration] mutableCopy];
    if ([[sender title] isEqualToString:NSLocalizedString(@"All FCC/IC Channels (1-11)", "menu item. needs to be the same as in MainMenu.nib")]) {
        for(y=1; y<=11; y++)
            [md setObject:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"useChannel%.2i", y]];

        [md setObject:[NSNumber numberWithInt:0] forKey:[NSString stringWithFormat:@"useChannel%.2i", 12]];
        [md setObject:[NSNumber numberWithInt:0] forKey:[NSString stringWithFormat:@"useChannel%.2i", 13]];
     } else {
        for(y=1; y<=13; y++)
            [md setObject:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"useChannel%.2i", y]];
    }
    
    [wd setConfiguration: md];
    [md release];
    
    [self updateChannelMenu];
}

- (IBAction)selDriver:(id)sender {
    NSUserDefaults *sets;

    sets = [NSUserDefaults standardUserDefaults];
    [sets setObject:[sender title] forKey:@"whichDriver"];
    [self updateChannelMenu];
}

- (IBAction)setAutoAdjustTimer:(id)sender {
    WaveDriver *wd;
    NSMutableDictionary *md;
    
    wd = [WaveHelper driverWithName:_whichDriver];
    if (!wd) {
        NSLog(@"Error: invalid driver selected");
        return;
    }
    
    md = [[wd configuration] mutableCopy];
    [md setObject:[NSNumber numberWithBool:(([sender state]==NSOffState) ? YES : NO)] forKey:@"autoAdjustTimer"];
 
    [wd setConfiguration: md];
    [md release];
    
    [self updateChannelMenu];

}
#pragma mark -
#pragma mark NETWORK MENU
#pragma mark -

- (IBAction)clearNetwork:(id)sender {
    WaveNet* net = _curNet;
    
    if (!_curNet) {
        NSBeep();
        return;
    }
    
    if (sender!=self) {
        NSBeginAlertSheet(
            NSLocalizedString(@"Really want to delete?", "Network deletion dialog title"),
            NSLocalizedString(@"Delete", "Network deletion dialog button"),
            NSLocalizedString(@"Delete and Filter", "Network deletion dialog button"),
            CANCEL, _window, self, NULL, @selector(reallyWantToDelete:returnCode:contextInfo:), self,
            NSLocalizedString(@"Network deletion dialog text", "LONG description of what this dialog does")
            //@"Are you sure that you whish to delete the network? This action cannot be undone. You may also choose to add the network to the filter list in the preferences and prevent it from re-appearing."
            );
        return;
    }
           
    [_window setDocumentEdited:YES];
    
    [self clearAreaMap];
    [self hideDetails];
    [self showNetworks];
    [_networkTable deselectAll:self];
    
    if (net) {
        if ([[net ID] isEqualToString:_activeAttackNetID]) [self stopActiveAttacks];
        [scanner clearNetwork:net];
    }
    _curNet = Nil;
    
    [self refreshScanHierarch];
    [self updateNetworkTable:self complete:YES];
}

- (void)reallyWantToDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSUserDefaults *sets;
    NSMutableArray *temp;
    NSString *mac;
    
    switch (returnCode) {
    case NSAlertDefaultReturn:
        [self clearNetwork:self];
    case NSAlertOtherReturn:
        break;
    case NSAlertAlternateReturn:
    default:
        sets=[NSUserDefaults standardUserDefaults];
        temp = [NSMutableArray arrayWithArray:[sets objectForKey:@"FilterBSSIDList"]];
        mac = [_curNet ID];
        
        if (mac!=Nil && [temp indexOfObject:mac]==NSNotFound) {
            [temp addObject:mac];
            [sets setObject:temp forKey:@"FilterBSSIDList"];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACFiltersChanged object:self];

        [self clearNetwork:self];
    }
}

- (IBAction)joinNetwork:(id)sender {
    [_curNet joinNetwork];
}

#pragma mark -

- (IBAction)injectPackets:(id)sender {
    //NSRunAlertPanel(@"Warning", @"I am not quiet happy with this function. It currently needs two cards. One Airport Card (needs to be set as default) and one PrismII Card. Orinoco cards will not work!\n\n What does packet reinjection?\n In this version KisMAC will re-send ARP-packets into an WEP-enabled network. This will cause a response. Basically it generates a lot of traffic, which will enable us to break into not busy networks. Do a deauthentication before injection, in order to make sure that there have been a couple of arp-packets.\n\nIf this works for you please drop me a mail.",
    //NULL, NULL, NULL);
    //return;    
    if ([aInjPacketsMenu state]==NSOffState && [self startActiveAttack]) {
        //either we are already active or we have to load the driver
        if (!_scanning) [self startScan];
        
        _crackType = 5;
        [self startCrackDialogWithTitle:NSLocalizedString(@"Setting up packet reinjection...", "busy dialog")];
        [_curNet reinjectWithImportController:_importController andScanner:scanner];
    
    } else {
        [self stopActiveAttacks];
    }
}
- (IBAction)deautheticateNetwork:(id)sender {
    if ([aDeauthMenu state]==NSOffState && [self startActiveAttack] && [scanner deauthenticateNetwork:_curNet atInterval:100]) {
        [aDeauthMenu setState:NSOnState];
        [aDeauthMenu setTitle:[NSLocalizedString(@"Deauthenticating ", "menu item") stringByAppendingString:[_curNet BSSID]]];
    } else {
        [self stopActiveAttacks];
    }
}
- (IBAction)authFloodNetwork:(id)sender {
    if ([_authFloodMenu state]==NSOffState && [self startActiveAttack] && [scanner authFloodNetwork:_curNet]) {
        [_authFloodMenu setState:NSOnState];
        [_authFloodMenu setTitle:[NSLocalizedString(@"Flooding ", "menu item") stringByAppendingString:[_curNet BSSID]]];
    } else {
        [self stopActiveAttacks];
    }
}

#pragma mark -
#pragma mark CRACK MENU
#pragma mark -

- (IBAction)weakCrackGeneric:(id)sender {
    if (([_curNet wep]==encryptionTypeWEP || [_curNet wep]==encryptionTypeWEP40)&&([_curNet weakPackets]<5)) {
        [self showNeedMoreWeakPacketsDialog];
    } else {
        if (_curNet==Nil) return;
        
        _crackType = 1;
        
        [self startCrackDialogWithTitle:NSLocalizedString(@"Weak key attack against WEP-40 & WEP-104...", "busy dialog")];
        [_importController setMax:32];
        [_curNet crackWithKeyByteLength:5 breath:4 import:_importController];
        [_curNet crackWithKeyByteLength:13 breath:2 import:_importController];
    }
}
- (IBAction)weakCrack40bit:(id)sender {
    if (([_curNet wep]==encryptionTypeWEP || [_curNet wep]==encryptionTypeWEP40)&&([_curNet weakPackets]<5)) {
        [self showNeedMoreWeakPacketsDialog];
    } else {
        if (_curNet==Nil) return;
        
        _crackType = 1;
        [self startCrackDialogWithTitle:NSLocalizedString(@"Weak key attack against WEP-40...", "busy dialog")];
        [_importController setMax:16];
        [_curNet crackWithKeyByteLength:5 breath:4 import:_importController];
    }
}
- (IBAction)weakCrack104bit:(id)sender {
    if (([_curNet wep]==encryptionTypeWEP || [_curNet wep]==encryptionTypeWEP40)&&([_curNet weakPackets]<5)) {
        [self showNeedMoreWeakPacketsDialog];
    } else {
        if (_curNet==Nil) return;
        
        _crackType = 1;
        [self startCrackDialogWithTitle:NSLocalizedString(@"Weak key attack against WEP-104...", "busy dialog")];
        [_importController setMax:17];
        [_curNet crackWithKeyByteLength:13 breath:2 import:_importController];
    }
}

- (IBAction)wordCrackWPA:(id)sender {
    if (_curNet==Nil) return;
    
    _crackType = 3;
    [self startCrackDialogWithTitle:NSLocalizedString(@"Wordlist attack against WPA...", "busy dialog")];
    [_curNet crackWPAWithImportController: _importController];
}

- (IBAction)wordCrackLEAP:(id)sender {
    if (_curNet==Nil) return;
    
    _crackType = 4;
    [self startCrackDialogWithTitle:NSLocalizedString(@"Wordlist attack against LEAP...", "busy dialog")];
    [_curNet crackLEAPWithImportController: _importController];
}

#pragma mark -
#pragma mark MAP MENU
#pragma mark -

- (IBAction)showCurNetArea:(id)sender {
   if ([sender state] == NSOffState) {
        [self stopScan];

        _importController = [[ImportController alloc] initWithWindowNibName:@"Crack"];
        [_importController setTitle: NSLocalizedString(@"Caching Map...", "Title of busy dialog")];
        [NSApp beginSheet:[_importController window] modalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        [WaveHelper setImportController:_importController];
        
        if ([_showAllNetsInMap state] == NSOnState) [self showAllNetArea:_showAllNetsInMap];
        [_mappingView showAreaNet:_curNet];
        
        [NSApp runModalForWindow:[_importController window]];
        
        [NSApp endSheet:[_importController window]];
        [[_importController window] close];
        [_importController stopAnimation];
        
        if ([_importController canceled]) {
            [_mappingView showAreaNet:Nil];
            [sender setTitle:@"Show Net Area"];
            [sender setState: NSOffState];
        } else {
            [sender setTitle:[NSLocalizedString(@"Show Net Area of ", "menu item") stringByAppendingString:[_curNet BSSID]]];
            [sender setState: NSOnState];
        }
        
        [_importController release];
        _importController=Nil;

    } else {
        [self clearAreaMap];
    }
}

- (IBAction)showAllNetArea:(id)sender {
    NSMutableArray *a;
    unsigned int i;
    
    if ([sender state] == NSOffState) {
        [self stopScan];
        
        _importController = [[ImportController alloc] initWithWindowNibName:@"Crack"];
        [_importController setTitle: NSLocalizedString(@"Caching Map...", "Title of busy dialog")];
    
        [NSApp beginSheet:[_importController window] modalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        [WaveHelper setImportController:_importController];
        
         if ([_showNetInMap state] == NSOnState) [self showCurNetArea:_showNetInMap];
    
        a = [[NSMutableArray alloc] init];
        for (i=0; i<[_container count]; i++) [a addObject:[_container netAtIndex:i]];
        [_mappingView showAreaNets:[NSArray arrayWithArray:a]];
        [a release];

        [NSApp runModalForWindow:[_importController window]];
        
        [NSApp endSheet:[_importController window]];
        [[_importController window] close];
        [_importController stopAnimation];
        
        if ([_importController canceled]) {
            [_mappingView showAreaNet:Nil];
            [sender setState: NSOffState];
        } else [sender setState: NSOnState];
        
        [_importController release];
        _importController=Nil;
    } else {
        [self clearAreaMap];
    }
}

- (IBAction)restartGPS:(id)sender {
    NSString *lDevice;
    
    lDevice=[[NSUserDefaults standardUserDefaults] objectForKey:@"GPSDevice"];
    if ((lDevice!=nil)&&(![lDevice isEqualToString:@""])) {
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACGPSStatusChanged object:NSLocalizedString(@"Resetting GPS subsystem...", "gps status")];
        [WaveHelper initGPSControllerWithDevice: lDevice];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:KisMACGPSStatusChanged object:NSLocalizedString(@"GPS disabled", "LONG GPS status string with informations where to enable")];
    }
}

#pragma mark -
#pragma mark WINDOW MENU
#pragma mark -

- (IBAction)closeActiveWindow:(id)sender {
    [[NSApp keyWindow] performClose:sender];
}

#pragma mark -
#pragma mark HELP MENU
#pragma mark -

- (IBAction)openWebsiteURL:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://kismac.binaervarianz.de"]];
}

- (IBAction)openDonateURL:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/xclick/business=charity%40binaervarianz.de&item_name=Support+for+KisMAC+Development"]];
}

- (IBAction)showContextHelp:(id)sender {
    switch(_visibleTab) {
    case tabNetworks:
        [[NSHelpManager sharedHelpManager] openHelpAnchor:@"KisMAC_Main_View" inBook:@"KisMAC Help"];
        break;
    case tabTraffic:
        [[NSHelpManager sharedHelpManager] openHelpAnchor:@"KisMAC_Traffic_View" inBook:@"KisMAC Help"];
        break;
    case tabMap:
        [[NSHelpManager sharedHelpManager] openHelpAnchor:@"KisMAC_Map_View" inBook:@"KisMAC Help"];
        break;
    case tabDetails:
        [[NSHelpManager sharedHelpManager] openHelpAnchor:@"KisMAC_Details_View" inBook:@"KisMAC Help"];
        break;
    default:
        NSAssert(NO, @"invalid visible tab");
    }
}

#pragma mark -
#pragma mark DEBUG MENU
#pragma mark -

- (IBAction)debugSaveStressTest:(id)sender {
    [NSThread detachNewThreadSelector:@selector(doDebugSaveStressTest:) toTarget:self withObject:nil];
}

- (IBAction)doDebugSaveStressTest:(id)anObject {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int i;
    
    for (i=0; i< 1500; i++) {
        if (![self save:@"~/stressTest.kismac"]) {
            NSLog(@"Stress test broken!");
            break;
        }
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    [pool release];
}

- (IBAction)gpsDebugToConsole:(id)sender {
    if ([sender state] == NSOffState) {
        [[WaveHelper gpsController] writeDebugOutput:YES];
        [sender setState: NSOnState];
    } else {
        [[WaveHelper gpsController] writeDebugOutput:NO];
        [sender setState: NSOffState];
    }
}


- (IBAction)debugBeaconFlood:(id)sender {
    if ([sender state]==NSOffState) {
        [self stopActiveAttacks];
        if (![scanner beaconFlood]) {
            NSLog(@"Could not start injectiong beacons like hell. Did you choose an injection driver?\n");
            return;
        }
        [sender setState:NSOnState];
    } else {
        [self stopActiveAttacks];
        [sender setState:NSOffState];
    }
}

- (IBAction)debugTestWPAHashingFunction:(id)sender {
    UInt8 output[40];
    int i, j;
    NSMutableString *ms;
    
    
    if (!wpaTestPasswordHash()) NSLog(@"WPA hash test failed");
    else NSLog(@"WPA hash test succeeded");
    
    wpaPasswordHash("password", "IEEE", 4, output);
    ms = [NSMutableString string];
    for (i=0; i < WPA_PMK_LENGTH; i++) {
        j = output[i];
        [ms appendFormat:@"%.2x", j];
    }
    NSLog(@"Testvector 1 returned: %@", ms);
    
    wpaPasswordHash("ThisIsAPassword", "ThisIsASSID", 11, output);
    ms = [NSMutableString string];
    for (i=0; i < WPA_PMK_LENGTH; i++) {
        j = output[i];
        [ms appendFormat:@"%.2x", j];
    }
    NSLog(@"Testvector 2 returned: %@", ms);
    
}

- (IBAction)debugExportTrafficView:(id)sender {
    [_trafficController outputTIFFTo:@"/test.tiff"];
}


@end
