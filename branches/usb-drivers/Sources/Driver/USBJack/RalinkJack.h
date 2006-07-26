/*
 *  RalinkJack.h
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "USBJack.h"

class RalinkJack: public USBJack
{
public:
    
    RalinkJack();
    ~RalinkJack();
    
private:
        int temp;
};

