/*
        
        File:			ScriptController.m
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

#import "ScriptController.h"
#import "ScanController.h"
#import "ScanControllerPrivate.h"
#import "ScanControllerScriptable.h"
#import "WaveHelper.h"
#import "ScriptAdditions.h"
#import "KisMACNotifications.h"

@implementation ScriptController

+ (BOOL)selfSendEvent:(AEEventID)event withClass:(AEEventClass)class andDefaultArg:(NSAppleEventDescriptor*)arg {
    AppleEvent  reply;
    ProcessSerialNumber	theCurrentProcess = { 0, kCurrentProcess };
    NSAppleEventDescriptor *target =  [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:(void*)&theCurrentProcess length:sizeof(theCurrentProcess)];    

    NSAppleEventDescriptor *e = [NSAppleEventDescriptor appleEventWithEventClass:class eventID:event targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    
    if (arg) [e setDescriptor:arg forKeyword:keyDirectObject];

    if(noErr != AESend([e aeDesc], &reply, kAEWaitReply, 0, kAEDefaultTimeout, NULL, NULL)) return NO;
    
    NSAppleEventDescriptor *replyDesc = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&reply] autorelease];
    NSAppleEventDescriptor *resultDesc = [replyDesc paramDescriptorForKeyword: keyDirectObject];
    
    if (resultDesc) return [resultDesc booleanValue];
    return YES;
}

+ (BOOL)selfSendEvent:(AEEventID)event withClass:(AEEventClass)class andDefaultArgString:(NSString*)arg {
    return [ScriptController selfSendEvent:event withClass:class andDefaultArg:[NSAppleEventDescriptor descriptorWithString:arg]];
}
+ (BOOL)selfSendEvent:(AEEventID)event withDefaultArgString:(NSString*)arg {
    return [ScriptController selfSendEvent:event withClass:'BIKM' andDefaultArgString:arg];
}
+ (BOOL)selfSendEvent:(AEEventID)event withDefaultArg:(NSAppleEventDescriptor*)arg {
    return [ScriptController selfSendEvent:event withClass:'BIKM' andDefaultArg:arg];
}
+ (BOOL)selfSendEvent:(AEEventID)event {
    return [ScriptController selfSendEvent:event withDefaultArg:nil];
}

#pragma mark -

- (id)init {
    self = [super init];
    if (!self) return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tryToSave:) name:KisMACTryToSave object:nil];

    return self;
}

- (void)tryToSave:(NSNotification*)note {
    [self saveKisMACFile:nil];
}

#pragma mark -

- (void)showWantToSaveDialog:(SEL)overrideFunction {
    NSBeginAlertSheet(
        NSLocalizedString(@"Save Changes?", "Save changes dialog title"),
        NSLocalizedString(@"Save", "Save changes dialog button"),
        NSLocalizedString(@"Don't Save", "Save changes dialog button"),
        CANCEL, [WaveHelper mainWindow], self, NULL, @selector(saveDialogDone:returnCode:contextInfo:), overrideFunction, 
        NSLocalizedString(@"Save changes dialog text", "LONG dialog text")
        );
}

- (void)saveDialogDone:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(SEL)overrideFunction {
    switch (returnCode) {
    case NSAlertDefaultReturn:
        [self saveKisMACFileAs:nil];
    case NSAlertOtherReturn:
        break;
    case NSAlertAlternateReturn:
    default:
        [self performSelector:overrideFunction withObject:self];
    }
}

#pragma mark -

- (IBAction)showNetworks:(id)sender {
    [ScriptController selfSendEvent:'KshN'];
}
- (IBAction)showTrafficView:(id)sender {
    [ScriptController selfSendEvent:'KshT'];
}
- (IBAction)showMap:(id)sender {
    [ScriptController selfSendEvent:'KshM'];
}
- (IBAction)showDetails:(id)sender {
    [ScriptController selfSendEvent:'KshD'];
}

- (IBAction)toggleScan:(id)sender {
    if ([sender state] == NSOnState) [ScriptController selfSendEvent:'KsoS'];
    else  [ScriptController selfSendEvent:'KsaS'];
}

#pragma mark -

- (IBAction)new:(id)sender {
    if ((sender!=self) && (![[NSApp delegate] isSaved])) {
        [self showWantToSaveDialog:@selector(new:)];
        return;
    }
   [ScriptController selfSendEvent:'KNew'];
}

#pragma mark -

- (IBAction)openKisMACFile:(id)sender {
    NSOpenPanel *op;
    
    if ((sender!=self) && (![[NSApp delegate] isSaved])) {
        [self showWantToSaveDialog:@selector(openKisMACFile:)];
        return;
    }

    op=[NSOpenPanel openPanel];
    [op setAllowsMultipleSelection:NO];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    if ([op runModalForTypes:[NSArray arrayWithObject:@"kismac"]]==NSOKButton) {
        [ScriptController selfSendEvent:'odoc' withClass:'aevt' andDefaultArgString:[op filename]];
    }
}

- (IBAction)openKisMAPFile:(id)sender {
    NSOpenPanel *op;
    
    op=[NSOpenPanel openPanel];
    [op setAllowsMultipleSelection:NO];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    if ([op runModalForTypes:[NSArray arrayWithObject:@"kismap"]]==NSOKButton) {
        [ScriptController selfSendEvent:'odoc' withClass:'aevt' andDefaultArgString:[op filename]];
    }
}

#pragma mark -

- (IBAction)importPCPFile:(id)sender {
    NSOpenPanel *op;
    int i;
    
    op = [NSOpenPanel openPanel];
    [op setAllowsMultipleSelection:YES];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    if ([op runModalForTypes:nil]==NSOKButton) {
        for (i = 0; i < [[op filenames] count]; i++)
            [ScriptController selfSendEvent:'KImP' withDefaultArgString:[[op filenames] objectAtIndex:i]];
    }

}

#pragma mark -

- (IBAction)saveKisMACFile:(id)sender {
    NSString *filename = [[NSApp delegate] filename];
    if (!filename) [self saveKisMACFileAs:sender];
    
    if (![ScriptController selfSendEvent:'save' withClass:'core' andDefaultArgString:filename]) 
        [[NSApp delegate] showSavingFailureDialog];
}

- (IBAction)saveKisMACFileAs:(id)sender {
    NSSavePanel *sp;
    
    sp=[NSSavePanel savePanel];
    [sp setRequiredFileType:@"kismac"];
    [sp setCanSelectHiddenExtension:YES];
    [sp setTreatsFilePackagesAsDirectories:NO];
    if ([sp runModal]==NSFileHandlingPanelOKButton) {
        if (![ScriptController selfSendEvent:'save' withClass:'core' andDefaultArgString:[sp filename]]) 
            [[NSApp delegate] showSavingFailureDialog];    
    }
}

- (IBAction)saveKisMAPFile:(id)sender {
    NSSavePanel *sp;
    
    sp=[NSSavePanel savePanel];
    [sp setRequiredFileType:@"kismap"];
    [sp setCanSelectHiddenExtension:YES];
    [sp setTreatsFilePackagesAsDirectories:NO];
    if ([sp runModal]==NSFileHandlingPanelOKButton) {
        if (![ScriptController selfSendEvent:'save' withClass:'core' andDefaultArgString:[sp filename]]) 
            [[NSApp delegate] showSavingFailureDialog];    
    }
}

#pragma mark -

#define WEPCHECKS {\
    if (![[NSApp delegate] selectedNetwork]) { NSBeep(); return; }\
    if ([[[NSApp delegate] selectedNetwork] passwordAvailable]) { [[NSApp delegate] showAlreadyCrackedDialog]; return; } \
    if ([[[NSApp delegate] selectedNetwork] wep] != encryptionTypeWEP && [[[NSApp delegate] selectedNetwork] wep] != encryptionTypeWEP40) { [[NSApp delegate] showWrongEncryptionType]; return; } \
    if ([[[[NSApp delegate] selectedNetwork] weakPacketsLog] count] < 10) { [[NSApp delegate] showNeedMorePacketsDialog]; return; } \
    }

- (IBAction)bruteforceNewsham:(id)sender {
    WEPCHECKS;
    [ScriptController selfSendEvent:'KCBN'];
}

- (IBAction)bruteforce40bitLow:(id)sender {
    WEPCHECKS;
    [ScriptController selfSendEvent:'KCBL'];
}

- (IBAction)bruteforce40bitAlpha:(id)sender {
    WEPCHECKS;
    [ScriptController selfSendEvent:'KCBa'];
}

- (IBAction)bruteforce40bitAll:(id)sender {
    WEPCHECKS;
    [ScriptController selfSendEvent:'KCBA'];
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
