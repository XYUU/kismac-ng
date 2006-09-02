/*
 *  RalinkJack.h
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */
#ifndef	__RALINKJACK_H__
#define	__RALINKJACK_H__

#import <Cocoa/Cocoa.h>
#import "USBJack.h"
#include "rt2570.h"

class RalinkJack: public USBJack
{
public:
    
    RalinkJack();
    ~RalinkJack();
    IOReturn RalinkJack::_init();
    
    IOReturn	RTUSB_VendorRequest(UInt8 direction,
                            UInt8 bRequest, 
                            UInt16 wValue, 
                            UInt16 wIndex, 
                            void *pData,
                            UInt16 wLength,
                            bool swap);
    
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
    
    IOReturn	RTUSBWriteBBPRegister(unsigned char Id,
                                      unsigned char Value);
    
    IOReturn	RalinkJack::RTUSBWriteRFRegister(unsigned long Value);
    
    IOReturn	RTUSBReadEEPROM(unsigned short Offset,
                                unsigned char * pData,
                                unsigned short length);
    
    void	NICReadEEPROMParameters();
    void    NICInitAsicFromEEPROM();
    
    bool setChannel(UInt16 channel);
    bool getAllowedChannels(UInt16* channels);
    bool startCapture(UInt16 channel);
    
    bool _massagePacket(int len);
    
private:
        int temp;
        unsigned short EEPROMDefaultValue[NUM_EEPROM_BBP_PARMS];
        unsigned short EEPROMBBPTuningParameters[NUM_EEPROM_BBP_TUNING_PARMS];
        BBP_TUNING_PARAMETERS_STRUC			BBPTuningParameters;
        unsigned char RfType;

};
#endif
