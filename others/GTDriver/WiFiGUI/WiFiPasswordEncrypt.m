/*
        
        File:			WiFiPasswordEncrypt.m
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

#import "WiFiPasswordEncrypt.h"
#include <openssl/md5.h>
#include <Security/Security.h>

typedef UInt8 WirelessKey[13]; // For use with WirelessEncrypt

extern SInt32 WirelessEncrypt(
        CFStringRef inNetworkPassword,
        WirelessKey *wepKey,
        const UInt32 use104bits);

/*
 * generate 104-bit key based on the supplied string
 */
inline void WirelessCryptMD5(char const *str, unsigned char *key) {
    int i, j;
    u_char md5_buf[64];
    MD5_CTX ctx;

    j = 0;
    for(i = 0; i < 64; i++) {
        if(str[j] == 0) j = 0;
        md5_buf[i] = str[j++];
    }

    MD5_Init(&ctx);
    MD5_Update(&ctx, md5_buf, 64);
    MD5_Final(md5_buf, &ctx);
    
    memcpy(key, md5_buf, 13);
}

@implementation WiFiPasswordEncrypt

+ (NSArray*)encryptionTechnics {
    return [NSArray arrayWithObjects:@"None", @"WEP Password 40-bit", @"WEP Password 128-bit", @"WEP 40/128-bit hex", @"WEP 40-bit ASCII", @"WEP 128-bit ASCII", nil];
}

+ (NSData*)hashPassword:(NSString*)password forType:(int)type {
    UInt8 ckey[13];
    UInt32 keylen, i, val, shift;
    NSMutableString *key;
    NSString *k;
    const char *c;
    int tmp;
    
    switch(type) {
        case 0:
            return [NSData data];
        case 1:        
            WirelessEncrypt((CFStringRef)password,(WirelessKey*)ckey,0);
            keylen = 5;
            break;
        case 2:
            WirelessEncrypt((CFStringRef)password,(WirelessKey*)ckey,1);
            keylen = 13;
            break;
        case 3:
            k = [password lowercaseString];
            if ([k length]) k = [k stringByTrimmingCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]];
    
            key = [NSMutableString stringWithString:k];
            [key replaceOccurrencesOfString:@":" withString:@"" options:0 range:NSMakeRange(0, [key length])];
            
            keylen = [key length];
            NSAssert(keylen==26 || keylen==10, @"Invalid hex key length"); 
            
            keylen /= 2;
            c = [key cString];
            for (i=0; i<keylen; i++) {
                NSAssert(sscanf(&c[i*2],"%2x", &tmp) == 1, @"Strange encryption string");
                ckey[i] = tmp & 0xFF;
            }
            break;
        case 4:
            c = [password cString];
        
            val = 0;
            for(i = 0; i < [password cStringLength]; i++) {
                shift = i & 0x3;
                val ^= (c[i] << (shift * 8));
            }
            
            for(i = 0; i < 5; i++) {
                val *= 0x343fd;
                val += 0x269ec3;
                ckey[i] = val >> 16;
            }

            keylen = 5;
            break;
        case 5:
            WirelessCryptMD5([password cString], ckey);
            keylen = 13;
            break;
            
        default:
            NSParameterAssert(type <= 5 && type >= 0);
            return nil;
    }
    
    return [NSData dataWithBytes:ckey length:keylen];
}

+ (BOOL)validPassword:(NSString*)password forType:(int)type {
    UInt32 keylen;
    NSMutableString *key;
    NSString *k;

    switch(type) {
        case 0:
            return YES;
        case 1:        
        case 2:
        case 4:
        case 5:
            return [password cStringLength] > 0;
        case 3:
            k = [password lowercaseString];
            if ([k length]) k = [k stringByTrimmingCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]];
    
            key = [NSMutableString stringWithString:k];
            [key replaceOccurrencesOfString:@":" withString:@"" options:0 range:NSMakeRange(0, [key length])];
            
            keylen = [key length];
            return (keylen==26 || [key length]==10); 
        default:
            NSParameterAssert(type <= 5 && type >= 0);
            return NO;
    }
    
    return NO;
}

//Call SecKeychainAddGenericPassword to add a new password to the keychain:
+ (bool) storePassword:(NSString*)password forAccount:(NSString*)account {
    OSStatus status;
    
    if (![self changePasswordForAccount:account toPassword:password]) {    
        status = SecKeychainAddGenericPassword (
            NULL,                   // default keychain
            15,                         // length of service name
            "AirPort Network",          // service name
            [account cStringLength],// length of account name
            [account cString],      // account name
            [password cStringLength],// length of password
            [password cString],     // pointer to password data
            NULL                    // the item reference
        );

        return (status == noErr);
    } 
    
    return YES;
}

	
//Call SecKeychainFindGenericPassword to get a password from the keychain:
+ (NSString*) getPasswordForAccount:(NSString*)account {
    OSStatus status ;
    SecKeychainItemRef itemRef;
    UInt32 myPasswordLength = 0;
    void *passwordData = nil;
    NSString *pwd;
    
    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        15,                         // length of service name
        "AirPort Network",          // service name
        [account cStringLength],    // length of account name
        [account cString],          // account name
        &myPasswordLength,          // length of password
        &passwordData,              // pointer to password data
        &itemRef                    // the item reference
    );


    if (status != noErr) return nil;
    
    pwd = [NSString stringWithCString:passwordData length:myPasswordLength];
    
    status = SecKeychainItemFreeContent (
         NULL,           //No attribute data to release
         passwordData    //Release data buffer allocated by SecKeychainFindGenericPassword
    );
    
    if (itemRef) CFRelease(itemRef);

    return pwd;
 }

+ (bool)deletePasswordForAccount:(NSString*)account {
    OSStatus status;
    SecKeychainItemRef itemRef;

    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        15,                         // length of service name
        "AirPort Network",          // service name
        [account cStringLength],    // length of account name
        [account cString],          // account name
        NULL,                       // length of password
        NULL,                       // pointer to password data
        &itemRef                    // the item reference
    );

    if (status != noErr) return NO;

    status = SecKeychainItemDelete(itemRef);

    if (itemRef) CFRelease(itemRef);

    return (status == noErr);
}
	
//Call SecKeychainItemModifyAttributesAndData to change the password for // an item already in the keychain:
+ (bool)changePasswordForAccount:(NSString*)account toPassword:(NSString*)password {
    OSStatus status;
    SecKeychainItemRef itemRef;

    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        15,                         // length of service name
        "AirPort Network",          // service name
        [account cStringLength],    // length of account name
        [account cString],          // account name
        NULL,                       // length of password
        NULL,                       // pointer to password data
        &itemRef                    // the item reference
    );

    if (status != noErr) return NO;

    status = SecKeychainItemModifyAttributesAndData (
        itemRef,                    // the item reference
        NULL,                       // no change to attributes
        [password cStringLength],   // length of password
        (void*)[password cString]   // pointer to password data
    );

    if (itemRef) CFRelease(itemRef);

    return (status == noErr);
}
@end
