/*
 *  RalinkJack.h
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#include "USBJack.h"

class RalinkJack: public USBJack
{
public:
    
    RalinkJack();
    ~RalinkJack();
    IOReturn	RTUSB_VendorRequest(UInt8 direction,
                            UInt8 bRequest, 
                            UInt16 wValue, 
                            UInt16 wIndex, 
                            UInt16 wLength, 
                            void *pData, 
                            UInt32 wLenDone );
    
private:
        int temp;
};

