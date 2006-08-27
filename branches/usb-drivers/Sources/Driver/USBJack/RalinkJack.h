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
#include "rt2570.h"

class RalinkJack: public USBJack
{
public:
    
    RalinkJack();
    ~RalinkJack();
    IOReturn	RTUSB_VendorRequest(UInt8 direction,
                            UInt8 bRequest, 
                            UInt16 wValue, 
                            UInt16 wIndex, 
                            void *pData,
                            UInt16 wLength);
    
    IOReturn RTUSBSingleRead(unsigned short	Offset,
                             unsigned short	* pValue);
    
    IOReturn	RalinkJack::RTUSBSingleWrite(unsigned short	Offset,
                                             unsigned short Value);
    
    IOReturn    RTUSBWriteMACRegister(unsigned short Offset,
                                      unsigned short Value);
    
    IOReturn	RTUSBReadMACRegister(unsigned short Offset,
                                     unsigned short * pValue);
    
    IOReturn	RTUSBReadBBPRegister(unsigned char Id,
                                     unsigned char * pValue);
    
private:
        int temp;
};

