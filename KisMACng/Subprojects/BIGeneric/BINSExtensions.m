//
//  BINSExtensions.m
//  BIGeneric
//
//  Created by mick on Tue Jul 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "BINSExtensions.h"
#import <Carbon/Carbon.h>

static BOOL _alertDone;

@implementation NSWindow(BIExtension) 

- (void)alertSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    _alertDone = YES;
}

- (int)showAlertMessage:(NSString *)msg title:(NSString *)title button:(NSString *)button {
    NSAlert *alert;
    
    alert = [NSAlert alertWithMessageText:title defaultButton:button alternateButton:nil otherButton:nil informativeTextWithFormat:msg];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:self modalDelegate:self didEndSelector:@selector(alertSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
    return 0;
}

@end

@implementation NSString(BIExtension) 

- (NSString*)standardPath {
    NSMutableString *path;
    
    path = [NSMutableString stringWithString:self];
    [path replaceOccurrencesOfString:@":" withString:@"/" options:0 range:NSMakeRange(0, [path length])];
    return [path stringByStandardizingPath];
}

@end


@implementation NSNotificationCenter(BIExtension) 

+ (void)postNotification:(NSString*)notificationName {
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:nil];
}

@end


@implementation NSThread(BIExtension) 

+ (void)sleep:(NSTimeInterval)seconds {
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

@end