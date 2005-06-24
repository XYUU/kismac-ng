/*
        
        File:			HexNumberFormatter.m
        Program:		WiFiGUI
		Author:			Michael Rossberg
						mick@binaervarianz.de
		Description:	GTDriver is a free driver for PrismGT based cards under OS X.
                
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

#import "HexNumberFormatter.h"


@implementation HexNumberFormatter


- (NSString *)stringWithColons:(NSString*)input preCopy:(int)pre {
    NSMutableString *from, *to;
    
    from = [NSMutableString stringWithString:input];
    to = [NSMutableString string];

    if (pre) {
        [to appendFormat:@"%@:", [from substringToIndex:pre]];
        [from deleteCharactersInRange:NSMakeRange(0,pre)]; 
    }
    
    while ([from length] > 2) {
        [to appendFormat:@"%@:", [from substringToIndex:2]];
        [from deleteCharactersInRange:NSMakeRange(0,2)]; 
    }
    [to appendString:from];
    
    return to;
}
- (NSString *)stringWithColons:(NSString*)input {
    return [self stringWithColons:input preCopy:0];
}

- (NSString *)stringForObjectValue:(id)obj {
    NSScanner *s;
    NSString *str;
    NSMutableString *k = [NSMutableString stringWithString:[obj lowercaseString]];
    [k replaceOccurrencesOfString:@":" withString:@"" options:0 range:NSMakeRange(0, [k length])];
    
    s = [NSScanner scannerWithString:k];
    if (![s scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] intoString:&str]) str = @"";
    
    return [self stringWithColons:str];
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs {
    NSMutableAttributedString *as;
    int i;
    
    as = [[NSMutableAttributedString alloc] initWithString:[self stringForObjectValue:obj] attributes:attrs];
    
    for (i = 2; i < [as length]; i+=3) {
        [as setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor lightGrayColor], NSForegroundColorAttributeName, nil] range:NSMakeRange(i,1)];
    } 
    
    return [as autorelease];
}

- (NSString *)editingStringForObjectValue:(id)obj {
    NSScanner *s;
    NSString *k;
    NSMutableString *str;
    
    str = [NSMutableString stringWithString:[obj lowercaseString]];
    [str replaceOccurrencesOfString:@":" withString:@"" options:0 range:NSMakeRange(0, [str length])];

    s = [NSScanner scannerWithString:str];
    if (![s scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] intoString:&k]) k = @"";

    return k;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {    
    *obj = [self editingStringForObjectValue:string];
    return YES;
}


- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error {
    NSScanner *s;
    NSString *k;
    
    s = [NSScanner scannerWithString:[*partialStringPtr lowercaseString]];
    if (![s scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] intoString:&k]) k = @"";
    
    if ([k length] != [*partialStringPtr length]) return NO;
    if (![k isEqualToString:*partialStringPtr]) {
        *partialStringPtr = k;
        return NO;
    }
    [_callBackObj performSelectorOnMainThread:_callBackSel withObject:nil waitUntilDone:NO];
    
    return YES;
}

- (BOOL)setCallback:(SEL)selector forObject:(NSObject*)obj {
    _callBackObj = obj;
    _callBackSel = selector;
    return YES;
}
@end
