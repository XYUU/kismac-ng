/*
        
        File:			ScriptAdditions.m
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

#import "ScriptAdditions.h"
#import "ScanController.h"
#import "ScanControllerScriptable.h"

@implementation NSApplication (APLApplicationExtensions)

- (id)showNetworks:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] showNetworks]];
}
- (id)showTraffic:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] showTrafficView]];
}
- (id)showMap:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] showMap]];
}
- (id)showDetails:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] showDetails]];
}

#pragma mark -

- (id)startScan:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] startScan]];
}
- (id)stopScan:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] stopScan]];
}

#pragma mark -

- (id)new:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] new]];
}

- (id)save:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] save:[command directParameter]]];
}

- (id)importPCAP:(NSScriptCommand *)command {
    return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] importPCAP:[command directParameter]]];
}

#pragma mark -

- (id)selectNetworkWithBSSID:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] selectNetworkWithBSSID:[command directParameter]]];
}

- (id)selectNetworkAtIndex:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] selectNetworkAtIndex:[command directParameter]]];
}

- (id)networkCount:(NSScriptCommand *)command {
   return [NSNumber numberWithInt:[(ScanController*)[NSApp delegate] networkCount]];
}

#pragma mark -

- (id)busy:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] isBusy]];
}

#pragma mark -

- (id)bruteforceNewsham:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] bruteforceNewsham]];
}

- (id)bruteforce40bitLow:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] bruteforce40bitLow]];
}

- (id)bruteforce40bitAlpha:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] bruteforce40bitAlpha]];
}

- (id)bruteforce40bitAll:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] bruteforce40bitAll]];
}

- (id)wordlist40bitApple:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] wordlist40bitApple:[command directParameter]]];
}

- (id)wordlist104bitApple:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] wordlist104bitApple:[command directParameter]]];
}

- (id)wordlist104bitMD5:(NSScriptCommand *)command {
   return [NSNumber numberWithBool:[(ScanController*)[NSApp delegate] wordlist104bitMD5:[command directParameter]]];
}



@end
