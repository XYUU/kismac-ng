//
//  ScanControllerScriptable.m
//  KisMAC
//
//  Created by mick on Tue Jul 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "ScanControllerScriptable.h"
#import "ScanControllerPrivate.h"
#import "SpinChannel.h"
#import "WaveNetWEPCrack.h"
#import <BIGeneric/BIGeneric.h>

@implementation ScanController(ScriptableAdditions)

- (BOOL)isSaved {
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"dontAskToSave"] boolValue]) return YES; //dont bother the user if set in preferences
    if ([_window isDocumentEdited]) return [_networkTable numberOfRows]==0; //dont ask to save empty documentets
    return YES;
}

- (NSString*)filename {
    return _fileName;
}

- (WaveNet*)selectedNetwork {
    return _curNet;
}

#pragma mark -

- (BOOL)showNetworks {
    [self changedViewTo:tabNetworks contentView:_networkView];
    return YES;
}
- (BOOL)showTrafficView {
    [self changedViewTo:tabTraffic contentView:_trafficView];
    return YES;
}
- (BOOL)showMap {
    [self changedViewTo:tabMap contentView:_mapView];
    return YES;
}
- (BOOL)showDetails {
    if (!_curNet) {
        NSBeep();
        return NO;
    } 
    [self changedViewTo:tabDetails contentView:_detailsView];
    return YES;
}


- (BOOL)startScan {
    bool result;
    
    if ([WaveHelper loadDrivers]) {
        if ([[WaveHelper getWaveDrivers] count] == 0) {
            NSBeginAlertSheet(@"No driver selected.", NULL, NULL, NULL, _window, self, NULL, NULL, NULL, @"Please select a WiFi Driver in the Preferences Window!");
            return NO;
        }
        
        _scanning=YES;
        [_window setDocumentEdited:YES];
        [_channelProg startAnimation:self];
        [_scanButton setTitle:@" Stop Scan "];
        [_scanButton setState: NSOnState];
        result=[scanner startScanning];
    }
    
    [self updateChannelMenu];
    return YES;
}

- (BOOL)stopScan {
    bool result;
    
    result=[scanner stopScanning];
    [_channelProg stopAnimation:self];
    [_scanButton setTitle: NSLocalizedString(@" Start Scan ", "title of the scan button")];
    [_scanButton setState: NSOffState];
    _scanning=NO;
    
    [self updateChannelMenu];
    [_networkTable reloadData];

    return YES;
}

- (BOOL)new {
    [self showBusyWithText:NSLocalizedString(@"Resetting document...", "Status for busy dialog")];
    
    [self stopActiveAttacks];
    [self stopScan];

    [self clearAreaMap];
    [self hideDetails];
    [self showNetworks];
    [_networkTable deselectAll:self];

    [scanner clearAllNetworks];
    
    [_window setDocumentEdited:NO];
    _curNet = Nil;
    [WaveHelper secureRelease:&_fileName];
    
    [self refreshScanHierarch];    
    [self updateNetworkTable:self complete:YES];
    
    [self busyDone];
    return YES;
}

- (BOOL)open:(NSString*)filename {
    BOOL ret;
    
    NSParameterAssert(filename);
    
    filename = [filename standardPath];
    
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"kismac"]) {
        [self showBusyWithText:[NSString stringWithFormat:NSLocalizedString(@"Opening %@...", "Status for busy dialog"), [filename stringByAbbreviatingWithTildeInPath]]];
        
        [self new];
        [WaveHelper secureReplace:&_fileName withObject:filename];
        
        NS_DURING
            ret = [scanner loadFromFile:filename];
        NS_HANDLER
            ret = NO;
        NS_ENDHANDLER
        
        [self updateNetworkTable:self complete:YES];
        [self refreshScanHierarch];
        [_window setDocumentEdited:NO];
        
        [self busyDone];
        
        return ret;
    } else if ([[[filename pathExtension] lowercaseString] isEqualToString:@"kismap"]) {
        [self showBusyWithText:[NSString stringWithFormat:NSLocalizedString(@"Opening %@...", "Status for busy dialog"), [filename stringByAbbreviatingWithTildeInPath]]];
        
        [self clearAreaMap];
        
        ret = [[WaveHelper zoomPictureView] loadFromFile:filename];
        [self showMap];
        
        [self busyDone];
        
        return ret;
    } 
    
    NSLog(@"Warning unknow file format!");
    NSBeep();
    return NO;
}

- (BOOL)importPCAP:(NSString*)filename {
    NSParameterAssert(filename);
    filename = [filename standardPath];
    
    [self showBusyWithText:[NSString stringWithFormat:NSLocalizedString(@"Importing %@...", "Status for busy dialog"), [filename stringByAbbreviatingWithTildeInPath]]];  
    
    [self stopScan];
    [_networkTable deselectAll:self];
    
    NS_DURING
        [scanner readPCAPDump:filename];
        [self updateNetworkTable:self complete:YES];
        [_window setDocumentEdited:YES];
        [self busyDone];
        NS_VALUERETURN(YES, BOOL);
    NS_HANDLER
        NSBeep();
        NSLog(@"Import of %@ failed!", filename);
    NS_ENDHANDLER
    
    [self busyDone];
    return NO;
}

- (BOOL)save:(NSString*)filename {
    BOOL ret = NO;
    
    NSParameterAssert(filename);
    filename = [filename standardPath];
    
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"kismac"]) {
        [self showBusyWithText:[NSString stringWithFormat:NSLocalizedString(@"Saving to %@...", "Status for busy dialog"), [filename stringByAbbreviatingWithTildeInPath]]];  

        NS_DURING
            [self stopActiveAttacks];
            [self stopScan];
            ret = [scanner saveToFile:filename];
            [WaveHelper secureReplace:&_fileName withObject:filename];
            if (!ret) [self showSavingFailureDialog];
            else [_window setDocumentEdited: _scanning];
    
            [self busyDone];
            NS_VALUERETURN(ret, BOOL);
        NS_HANDLER
            NSLog(@"Saving failed, because of an internal error!");
        NS_ENDHANDLER

        [self busyDone];
    } else if ([[[filename pathExtension] lowercaseString] isEqualToString:@"kismap"]) {
        [self showBusyWithText:[NSString stringWithFormat:NSLocalizedString(@"Saving to %@...", "Status for busy dialog"), [filename stringByAbbreviatingWithTildeInPath]]];  

        NS_DURING
            [[WaveHelper zoomPictureView] saveToFile:filename];
            
            [self busyDone];
            NS_VALUERETURN(YES, BOOL);
        NS_HANDLER
            NSLog(@"Map saving failed, because of an internal error!");
            [self showSavingFailureDialog];
        NS_ENDHANDLER

        [self busyDone];
    } 
    
    NSLog(@"Warning unknow file format!");
    NSBeep();
    return NO;
}

#pragma mark -

- (BOOL)selectNetworkWithBSSID:(NSString*)BSSID {
    int i;
    
    NSParameterAssert(BSSID);
    
    for (i = [_container count]; i>=0; i--)
        if ([[[_container netAtIndex:i] BSSID] isEqualToString:BSSID]) {
            _selectedRow = i;
            [_networkTable selectRow:i byExtendingSelection:NO];
            return YES;
        }
        
    return NO;
}

- (BOOL)selectNetworkAtIndex:(NSNumber*)index {
    NSParameterAssert(index);
    
    int i = [index intValue];
    
    if (i < [_container count]) {
        _selectedRow = i;
        [_networkTable selectRow:i byExtendingSelection:NO];
        return YES;
    }
    
    return NO;
}

- (int) networkCount {
    return [_container count];
}

#pragma mark -

- (BOOL) isBusy {
    return _importOpen > 0;
}

#pragma mark -

#define WEPCHECKS {\
    if (_importOpen) return NO; \
    if (_curNet==Nil) return NO; \
    if ([_curNet passwordAvailable] != Nil) return YES; \
    if ([_curNet wep] != encryptionTypeWEP && [_curNet wep] != encryptionTypeWEP40) return NO; \
    if ([[_curNet weakPacketsLog] count] < 10) return NO; \
    }

- (BOOL)bruteforceNewsham {
    WEPCHECKS;
    
    [self showCrackBusyWithText:NSLocalizedString(@"Performing Newsham attack...", "busy dialog")];
    [_importController setMax:127];
    
    [NSThread detachNewThreadSelector:@selector(performBruteforceNewsham:) toTarget:_curNet withObject:nil];
    
    return YES;
}

- (BOOL)bruteforce40bitLow {
    WEPCHECKS;
    
    [self startCrackDialogWithTitle:NSLocalizedString(@"Bruteforce attack against WEP-40 lowercase...", "busy dialog")];
    [_importController setMax:26];
    
    [NSThread detachNewThreadSelector:@selector(performBruteforce40bitLow:) toTarget:_curNet withObject:nil];
    
    return YES;
}

- (BOOL)bruteforce40bitAlpha {
    WEPCHECKS;
    
    [self startCrackDialogWithTitle:NSLocalizedString(@"Bruteforce attack against WEP-40 alphanumerical...", "busy dialog")];
    [_importController setMax:62];
    
    [NSThread detachNewThreadSelector:@selector(performBruteforce40bitAlpha:) toTarget:_curNet withObject:nil];
    
    return YES;
}

- (BOOL)bruteforce40bitAll {
    WEPCHECKS;
    
    [self startCrackDialogWithTitle:NSLocalizedString(@"Bruteforce attack against WEP-40...", "busy dialog")];
    [_importController setMax:256];
    
    [NSThread detachNewThreadSelector:@selector(performBruteforce40bitAll:) toTarget:_curNet withObject:nil];
    
    return YES;
}


@end
