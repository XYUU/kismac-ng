/*
        
        File:			WiFiPasswordEncrypt.h
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


@interface WiFiPasswordEncrypt : NSObject {

}

+ (NSArray*)encryptionTechnics;
+ (NSData*)hashPassword:(NSString*)password forType:(int)type;
+ (BOOL)validPassword:(NSString*)password forType:(int)type;

+ (bool)storePassword:(NSString*)password forAccount:(NSString*)account;
+ (bool)deletePasswordForAccount:(NSString*)account;
+ (NSString*)getPasswordForAccount:(NSString*)account;
+ (bool)changePasswordForAccount:(NSString*)account toPassword:(NSString*)password;

@end
