//
//  ScanControllerScriptable.h
//  KisMAC
//
//  Created by mick on Tue Jul 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ScanController.h"

@interface ScanController(ScriptableAdditions)

- (BOOL)isSaved;
- (NSString*)filename;
- (WaveNet*)selectedNetwork;

- (BOOL)showNetworks;
- (BOOL)showTrafficView;
- (BOOL)showMap;
- (BOOL)showDetails;

- (BOOL)startScan;
- (BOOL)stopScan;

- (BOOL)new;
- (BOOL)open:(NSString*)filename;
- (BOOL)importPCAP:(NSString*)filename;
- (BOOL)save:(NSString*)filename;

- (BOOL)selectNetworkWithBSSID:(NSString*)BSSID;
- (BOOL)selectNetworkAtIndex:(NSNumber*)index;
- (int) networkCount;

- (BOOL)isBusy;

- (BOOL)bruteforceNewsham;
- (BOOL)bruteforce40bitLow;
- (BOOL)bruteforce40bitAlpha;
- (BOOL)bruteforce40bitAll;

- (BOOL)wordlist40bitApple:(NSString*)wordlist;
- (BOOL)wordlist104bitApple:(NSString*)wordlist;
- (BOOL)wordlist104bitMD5:(NSString*)wordlist;

@end
