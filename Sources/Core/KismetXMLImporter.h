//
//  KismetXMLImporter.h
//  KisMAC
//
//  Created by Geoffrey Kruse on 9/22/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "WaveContainer.h"


@interface KismetXMLImporter : NSObject {

     NSMutableString * currentStringValue;
     NSMutableArray * importedNets;
     NSMutableDictionary * currentNet;
}

- (NSDictionary *)performKismetImport: (NSString *)filename withContainer:(WaveContainer*)container;

@end
