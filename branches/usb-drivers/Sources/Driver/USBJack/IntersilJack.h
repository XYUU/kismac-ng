//
//  IntersilJack.h
//  KisMAC
//
//  Created by Geoffrey Kruse on 5/1/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "USBJack.h"

class IntersilJack: public USBJack
{
public:

    IntersilJack();
    ~IntersilJack();
    
private:
        int temp;
};


