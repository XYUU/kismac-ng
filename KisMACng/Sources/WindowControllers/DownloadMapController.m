/*
        
        File:			DownloadMapController.m
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

#import "DownloadMapController.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <netdb.h>
#import "KisMACNotifications.h"
#import "WaveHelper.h"

@implementation DownloadMapController 

- (void)awakeFromNib {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    
    [_scale  selectItemWithTitle:[def stringForKey:@"DownloadMapScale"]];
    [_server selectItemWithTitle:[def stringForKey:@"DownloadMapServer"]];
    [_width  setIntValue:[def integerForKey:@"DownloadMapWidth"]];
    [_height setIntValue:[def integerForKey:@"DownloadMapHeight"]];
    [_nsButton selectItemWithTitle:[def stringForKey:@"DownloadMapNS"]];
    [_ewButton selectItemWithTitle:[def stringForKey:@"DownloadMapEW"]];
    [_latitude  setFloatValue:[def floatForKey:@"DownloadMapLatitude"]];
    [_longitude setFloatValue:[def floatForKey:@"DownloadMapLongitude"]];
    
    [self selectOtherServer:_server];

    _mapLocation = Nil;
    [[self window] setDelegate:self];
    
}

- (IBAction)selectOtherServer:(id)sender {
    BOOL map24 = [[sender titleOfSelectedItem] isEqualToString:@"Map24"];
    [_scale  setEnabled:!map24];
    [_height setEnabled:!map24];
    [_width  setEnabled:!map24];
    if (map24) {
        [_height setIntValue:1000];
        [_width  setIntValue:1000];
    }
}

- (IBAction)okAction:(id)sender {
    NSString *req, *error;
    int scale;
    float scalef, expediaFactorW, expediaFactorH;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    
    _wp._lat  = [_latitude  floatValue] * ([[_nsButton titleOfSelectedItem] isEqualToString:@"N"] ? 1.0 : -1.0);
    _wp._long = [_longitude floatValue] * ([[_ewButton titleOfSelectedItem] isEqualToString:@"E"] ? 1.0 : -1.0);
    
    _p1.x = [_width floatValue] / 2.0;
    _p1.y = [_height floatValue] / 2.0;
    _wp1 = _wp;
    _p2.x = 0;
    _p2.y = 0;
    _wp2._lat  = 0;
    _wp2._long = 0;

    if ([[_server titleOfSelectedItem] isEqualToString: NSLocalizedString(@"TerraServer (Satellite)", "menu item, needs to be like in DownloadMap.nib")]) {
        scale = 16 - [[_scale titleOfSelectedItem] intValue];
        req = [NSString stringWithFormat:
            @"http://terraserver-usa.com/GetImageArea.ashx?t=1&s=%d&lon=%f&lat=%f&w=%d&h=%d",
           scale, _wp._long, _wp._lat, [_width intValue], [_height intValue]];
    } else if ([[_server titleOfSelectedItem] isEqualToString: NSLocalizedString(@"TerraServer (Map)", "menu item, needs to be like in DownloadMap.nib")]) {
        scale = 16 - [[_scale titleOfSelectedItem] intValue];
        req = [NSString stringWithFormat:
            @"http://terraserver-usa.com/GetImageArea.ashx?t=2&s=%d&lon=%f&lat=%f&w=%d&h=%d",
           scale, _wp._long, _wp._lat, [_width intValue], [_height intValue]];
    } else if ([[_server titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Expedia (United States)", "menu item, needs to be like in DownloadMap.nib")]) {
        int sockd;
        struct sockaddr_in serv_name;
        char buf[2024];
        int status;
        struct hostent *hp;
        u_long ip;
        int bytesread;
        NSString *s;
        int errcount = 0;
        CFHTTPMessageRef myMessage;
        
        scale = 6 - [[_scale titleOfSelectedItem] intValue];
        req = [NSString stringWithFormat:
            @"http://www.expedia.com/pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=0409USA&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0", 
            _wp._lat, _wp._long, scale, [_width intValue], [_height intValue]];
        /*
        NSDictionary *dic;
        NSHTTPCookieStorage *cookiestore;
        NSHTTPCookie *cookie;
        
        NS_DURING
            cookiestore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            if (cookiestore) {
                if ([cookiestore cookieAcceptPolicy]==NSHTTPCookieAcceptPolicyNever) {
                    NSLog(@"Error: Cookies disabled!");
                    NSBeginAlertSheet(@"Cookies disabled.",nil,nil,nil,[self window],nil,nil,nil,nil,
                    @"The Expedia server requires cookies to be enabled! Since KisMAC uses the same sub-system as Safari, you will need to open it and enable cookies. \
You can also select another server, which does not require cookies. You can also select the \"accept cookies from the site you navigate to\" option \
in Safari.");
                    NS_VOIDRETURN;
                }
                dic = [NSDictionary dictionaryWithObjectsAndKeys:@"http://www.expedia.com/", NSHTTPCookieOriginURL, @"jscript", NSHTTPCookieName, @"1", NSHTTPCookieValue, nil];
                cookie = [NSHTTPCookie cookieWithProperties:dic];
                if (cookie) [cookiestore setCookie:cookie];
                else NSLog(@"Critical Error: Could not create cookie!");
            } else {
                NSLog(@"Error: Cookie Storage unavailable. Operating System needs to be 10.2.6 with Safari 1.0 intalled!");
                NSBeginAlertSheet(@"Invalid Operating System.",nil,nil,nil,[self window],nil,nil,nil,nil,
                @"The Expedia server requires a complete browser system in order to send maps. KisMAC can provide this, however you will need at least a MacOS X 10.2.6 installation, with Safari 1.0 or higher installed!");
                NS_VOIDRETURN;
            }
        NS_HANDLER
            NSLog(@"Error: Cookie Storage unavailable. Operating System needs to be 10.2.6 with Safari 1.0 intalled!");
            NSBeginAlertSheet(@"Invalid Operating System.",nil,nil,nil,[self window],nil,nil,nil,nil,
            @"The Expedia server requires a complete browser system in order to send maps. KisMAC can provide this, however you will need at least a MacOS X 10.2.6 installation, with Safari 1.0 or higher installed!");
            return;
        NS_ENDHANDLER*/
        
        [_okButton setEnabled:NO];
        [_cancelButton setEnabled:NO];
        
        sockd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockd == -1) {
            error = @"Socket creation failed!";
            goto err;
        }
	
        hp = gethostbyname("www.expedia.com");
        if (hp == NULL) {
            error = NSLocalizedString(@"Could not resolve www.expedia.com", "Download Map Error");;
            goto err;
        }
        ip = *(int *)hp->h_addr_list[0];
    
        /* server address */ 
        serv_name.sin_family = AF_INET;
        serv_name.sin_addr.s_addr = ip;
        serv_name.sin_port = htons(80);
        
        NSLog(@"Connecting to expedia (%s, %x)",inet_ntoa(serv_name.sin_addr),ip );
        
        /* connect to the server */
        status = connect(sockd, (struct sockaddr*)&serv_name, sizeof(serv_name));
        if (status == -1) {
            error = NSLocalizedString(@"Could not connect to www.expedia.com", "Download Map Error");;
            goto err;
        }
        
        s = [NSString stringWithFormat:@"GET /pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=0409USA&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0 HTTP/1.0\nHost: www.expedia.com\nCookie: jscript=1\nConnection: close\n\n", 
            _wp._lat, _wp._long, scale, [_width intValue], [_height intValue]];

        NSLog(@"Sending request to expedia");
        write(sockd, [s cString], [s length]);
        s = [NSString string];
        
        NSLog(@"Reading response from expedia");
        
        bytesread = read(sockd, buf, 2024);
        while ((bytesread != -1) && ([s length] < 1100)) {
            if (bytesread==0) {
                errcount++;
                if (errcount = 60) {
                    error = NSLocalizedString(@"Got no response from expedia. Mapsize too big?", "Download Map Error");
                    goto err;
                }
                [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            } else {
                errcount = 0;
                s = [s stringByAppendingString:[NSString stringWithCString:buf length:bytesread]];
            }
            bytesread = read(sockd, buf, 2024);
        }
        
        NSLog(@"Response from expedia %@",s);
        
        myMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
        if (!CFHTTPMessageAppendBytes(myMessage, [s cString], [s length])) {
            error = @"CFTTPResponse Parsing error";
            close(sockd);
            goto err;
        }
        
        if (!CFHTTPMessageIsHeaderComplete(myMessage)) {
            error = @"Incomplete Headers!";
            goto err;
        }
        
        req = (NSString*)CFHTTPMessageCopyHeaderFieldValue(myMessage, CFSTR("Location"));
        NSLog(@"New location is at %@", req);
        
        switch(scale) {
            case 5:
                expediaFactorH = 15900;
                expediaFactorW = 16030.76934;
                break;
            case 4:
                expediaFactorH = 19900;
                expediaFactorW = 19953.19163;
                break;
            case 3:
                expediaFactorH = 26500;
                expediaFactorW = 26433.71541;
                break;
            case 2:
                expediaFactorH = 39800;
                expediaFactorW = 39703.79291;
                break;
            case 1:
                expediaFactorH = 79600;
                expediaFactorW = 79812.76652;
                break;
            default:
                expediaFactorH = 0;
                expediaFactorW = 0;
                NSLog(@"Warning Invalid Zoom Size!");
                NSBeep();
        }
        
        if (expediaFactorW) {
            expediaFactorH *= 2; //for the half map only
            expediaFactorW *= 2; //for the half map only
            
            _p1.x = [_width floatValue];
            _p1.y = [_height floatValue];
            _wp1._lat  = _wp._lat  + [_height floatValue] / expediaFactorH;
            _wp1._long = _wp._long + [_width  floatValue] / (expediaFactorW * cos(_wp1._lat * 0.017453292)); //the width depends on latitude
            _p2.x = 0;
            _p2.y = 0;
            _wp2._lat  = _wp._lat  - [_height floatValue] / expediaFactorH;
            _wp2._long = _wp._long - [_width  floatValue] / (expediaFactorW  * cos(_wp2._lat * 0.017453292)); //the width depends on latitude
        }
        
        close(sockd);
    } else if ([[_server titleOfSelectedItem] isEqualToString:NSLocalizedString(@"Expedia (Europe)", "menu item, needs to be like in DownloadMap.nib")]) {
        int sockd;
        struct sockaddr_in serv_name;
        char buf[2024];
        int status;
        struct hostent *hp;
        u_long ip;
        int bytesread;
        NSString *s;
        int errcount = 0;
        CFHTTPMessageRef myMessage;
        
        scale = 6 - [[_scale titleOfSelectedItem] intValue];
        req = [NSString stringWithFormat:
            @"http://www.expedia.de/pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=EUR0407&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0", 
            _wp._lat, _wp._long, scale, [_width intValue], [_height intValue]];
         
        [_okButton setEnabled:NO];
        [_cancelButton setEnabled:NO];
        
        sockd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockd == -1) {
            error = @"Socket creation failed!";
            goto err;
        }
	
        hp = gethostbyname("www.expedia.de");
        if (hp == NULL) {
            error = NSLocalizedString(@"Could not resolve www.expedia.de", "Download Map Error");;
            goto err;
        }
        ip = *(int *)hp->h_addr_list[0];
    
        /* server address */ 
        serv_name.sin_family = AF_INET;
        serv_name.sin_addr.s_addr = ip;
        serv_name.sin_port = htons(80);
        
        NSLog(@"Connecting to expedia (%s, %x)",inet_ntoa(serv_name.sin_addr),ip );
        
        /* connect to the server */
        status = connect(sockd, (struct sockaddr*)&serv_name, sizeof(serv_name));
        if (status == -1) {
            error = NSLocalizedString(@"Could not connect to www.expedia.com", "Download Map Error");;
            goto err;
        }
        
        s = [NSString stringWithFormat:@"GET /pub/agent.dll?qscr=mrdt&CenP=%f,%f&Lang=EUR0407&Alti=%d&MapS=0&Size=%d,%d&Offs=0.000000,0 HTTP/1.0\nHost: www.expedia.de\nCookie: jscript=1\nConnection: close\n\n", 
            _wp._lat, _wp._long, scale, [_width intValue], [_height intValue]];

        NSLog(@"Sending request to expedia");
        write(sockd, [s cString], [s length]);
        s = [NSString string];
        
        NSLog(@"Reading response from expedia");
        
        bytesread = read(sockd, buf, 2024);
        while ((bytesread != -1) && ([s length] < 1100)) {
            if (bytesread==0) {
                errcount++;
                if (errcount = 60) {
                    error = NSLocalizedString(@"Got no response from expedia. Mapsize too big?", "Download Map Error");
                    goto err;
                }
                [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            } else {
                errcount = 0;
                s = [s stringByAppendingString:[NSString stringWithCString:buf length:bytesread]];
            }
            bytesread = read(sockd, buf, 2024);
        }
        
        NSLog(@"Response from expedia.");
        
        myMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
        if (!CFHTTPMessageAppendBytes(myMessage, [s cString], [s length])) {
            error = @"CFTTPResponse Parsing error";
            close(sockd);
            goto err;
        }
        
        if (!CFHTTPMessageIsHeaderComplete(myMessage)) {
            error = @"Incomplete Headers!";
            goto err;
        }
        
        req = (NSString*)CFHTTPMessageCopyHeaderFieldValue(myMessage, CFSTR("Location"));
        NSLog(@"New location is at %@", req);
        
        switch(scale) {
            case 5:
                expediaFactorH = 15900;
                expediaFactorW = 16030.76934;
                break;
            case 4:
                expediaFactorH = 19900;
                expediaFactorW = 19953.19163;
                break;
            case 3:
                expediaFactorH = 26500;
                expediaFactorW = 26433.71541;
                break;
            case 2:
                expediaFactorH = 39800;
                expediaFactorW = 39703.79291;
                break;
            case 1:
                expediaFactorH = 79600;
                expediaFactorW = 79812.76652;
                break;
            default:
                expediaFactorH = 0;
                expediaFactorW = 0;
                NSLog(@"Warning Invalid Zoom Size!");
                NSBeep();
        }
        
        if (expediaFactorW) {
            expediaFactorH *= 2; //for the half map only
            expediaFactorW *= 2; //for the half map only
            
            _p1.x = [_width floatValue];
            _p1.y = [_height floatValue];
            _wp1._lat  = _wp._lat  + [_height floatValue] / expediaFactorH;
            _wp1._long = _wp._long + [_width  floatValue] / (expediaFactorW * cos(_wp1._lat * 0.017453292)); //the width depends on latitude
            _p2.x = 0;
            _p2.y = 0;
            _wp2._lat  = _wp._lat  - [_height floatValue] / expediaFactorH;
            _wp2._long = _wp._long - [_width  floatValue] / (expediaFactorW  * cos(_wp2._lat * 0.017453292)); //the width depends on latitude
        }
        
        close(sockd);
    } else if ([[_server titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Map24", "menu item, needs to be like in DownloadMap.nib")]) {
        req = [NSString stringWithFormat:
            @"http://maptp.map24.com/map24/cgi?locid0=tmplocid0&wx0=%f&wy0=%f&iw=%d&ih=%d&mid=MAP24", 
            _wp._long * 60.0, _wp._lat * 60.0, [_width intValue], [_height intValue]];    
  
            _p1.x = [_width floatValue];
            _p1.y = [_height floatValue];
            _p2.x = 0;
            _p2.y = 0;
            
            //0.017453292 is for degree to rad conversion
            _wp1._lat  = _wp._lat  + [_height floatValue] / (1040.0 * 2 * 60.0 * cos(_wp._lat  * 0.017453292));
            _wp1._long = _wp._long + [_width  floatValue] / (712.0  * 2 * 60.0 * cos(_wp1._lat * 0.017453292)); //the width depends on latitude
            _wp2._lat  = _wp._lat  - [_height floatValue] / (1040.0 * 2 * 60.0 * cos(_wp._lat  * 0.017453292));
            _wp2._long = _wp._long - [_width  floatValue] / (712.0  * 2 * 60.0 * cos(_wp2._lat * 0.017453292)); //the width depends on latitude
    } else if ([[_server titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Census Bureau Maps (United States)", "menu item, needs to be like in DownloadMap.nib")]) {
        scalef = [[_scale titleOfSelectedItem] floatValue];
        
        req = [NSString stringWithFormat:
            @"http://tiger.census.gov/cgi-bin/mapper/map.gif?&lat=%f&lon=%f&ht=%f&wid=%f&conf=mapnew.con&iht=%d&iwd=%d",
            _wp._lat, _wp._long, 0.065/scalef, 0.180/scalef, [_height intValue], [_width intValue]];
    } else {
        NSRunCriticalAlertPanel(
            NSLocalizedString(@"No server selected.", "Download Map error title"),
            NSLocalizedString(@"No server selected. description", "LONG error description"),
            //@"KisMAC needs the name of a server from where it can load the map. Depending on your region and the look of the map you should find one in the pop-up menu. If you know how-to obtain a map from another server, please drop me a mail.",
            OK, nil, nil
            );
        return;
    }
    _mapLocation = [[NSURL URLWithString:req] retain];
    NSLog(@"Try to load map from the following location: %@", req);
    
    [def setObject:[_scale titleOfSelectedItem] forKey:@"DownloadMapScale"];
    [def setObject:[_server titleOfSelectedItem] forKey:@"DownloadMapServer"];
    [def setInteger:[_width intValue] forKey:@"DownloadMapWidth"];
    [def setInteger:[_height intValue] forKey:@"DownloadMapHeight"];
    [def setFloat:[_latitude floatValue] forKey:@"DownloadMapLatitude"];
    [def setFloat:[_longitude floatValue] forKey:@"DownloadMapLongitude"];
    [def setObject:[_nsButton titleOfSelectedItem] forKey:@"DownloadMapNS"];
    [def setObject:[_ewButton titleOfSelectedItem] forKey:@"DownloadMapEW"];

    [self close];
    
    return;
    
err:
    NSBeginAlertSheet(
        NSLocalizedString(@"Connection error.", "Download Map error title"), 
        OK, nil, nil,
        [self window], nil, nil, nil, nil,
        [NSString stringWithFormat:
            @"%@: %@", 
            NSLocalizedString(@"The connection to the server failed for the following reason", "Download Map error description"),
            error]
        );
    
    [_okButton setEnabled:YES];
    [_cancelButton setEnabled:YES];
}

- (IBAction)cancelAction:(id)sender {
    [self close];
}

- (void)setCoordinates:(waypoint)wp {
    _wp = wp;
    
    if (wp._lat==0 && wp._long==0) return;
    
    [_latitude  setFloatValue: ((wp._lat >= 0) ? wp._lat : -wp._lat) ];
    [_longitude setFloatValue: ((wp._long>= 0) ? wp._long: -wp._long)];
 
    if (wp._lat>=0)  [_nsButton selectItemWithTitle:@"N"];
    else  [_nsButton selectItemWithTitle:@"S"];
    
    if (wp._long>=0) [_ewButton selectItemWithTitle:@"E"];
    else  [_ewButton selectItemWithTitle:@"W"];
}
- (void)setCallback:(SEL)selector forObject:(NSObject*)obj {
    _selector = selector;
    _obj = obj;
}

- (NSURL*)mapLocation {
    return _mapLocation;
}

- (void)windowWillClose:(NSNotification *)aNotification {
    [_obj performSelectorOnMainThread:_selector withObject:self waitUntilDone:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:KisMACModalDone object:self];
}

- (void)dealloc {
    [_mapLocation release];
    _mapLocation=Nil;
    [super dealloc];
}

- (NSPoint)waypoint1Pixel {
    return _p1;
}

- (waypoint)waypoint1 {
    return _wp1;
}

- (NSPoint)waypoint2Pixel {
    return _p2;
}

- (waypoint)waypoint2 {
    return _wp2;
}

@end
