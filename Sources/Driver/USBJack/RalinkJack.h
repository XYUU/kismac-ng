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

//this stuff goes here for now because something is funkey with the include order
#define	NUM_EEPROM_BBP_PARMS		19
#define	NUM_EEPROM_BBP_TUNING_PARMS	7
#define UCHAR unsigned char

typedef struct _BBP_TUNING_PARAMETERS_STRUC
{
	UCHAR			BBPTuningThreshold;
	UCHAR			R24LowerValue;
	UCHAR			R24HigherValue;
	UCHAR			R25LowerValue;
	UCHAR			R25HigherValue;
	UCHAR			R61LowerValue;
	UCHAR			R61HigherValue;
	UCHAR			BBPR17LowSensitivity;
	UCHAR			BBPR17MidSensitivity;
	UCHAR			RSSIToDbmOffset;
	bool			LargeCurrentRSSI;
}
BBP_TUNING_PARAMETERS_STRUC, *PBBP_TUNING_PARAMETERS_STRUC;


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
    
    IOReturn	RTUSBSingleWrite(unsigned short	Offset,
                                             unsigned short Value);

    IOReturn    RTUSBWriteMACRegister(unsigned short Offset,
                                      unsigned short Value);
    
    IOReturn	RTUSBReadMACRegister(unsigned short Offset,
                                     unsigned short * pValue);
    
    IOReturn	RTUSBReadBBPRegister(unsigned char Id,
                                     unsigned char * pValue);
    
    IOReturn	RTUSBWriteBBPRegister(unsigned char Id,
                                      unsigned char Value);
    
    IOReturn	RTUSBWriteRFRegister(unsigned long Value);
    
    IOReturn	RTUSBReadEEPROM(unsigned short Offset,
                                unsigned char * pData,
                                unsigned short length);


    
    void	NICReadEEPROMParameters();
    void    NICInitAsicFromEEPROM();
    
    bool setChannel(UInt16 channel);
    bool getAllowedChannels(UInt16* channels);
    bool startCapture(UInt16 channel);
    bool stopCapture();
    
    bool _massagePacket(int len);
    int WriteTxDescriptor(WLFrame * theFrame);

    
private:
    int temp;
    unsigned short EEPROMDefaultValue[NUM_EEPROM_BBP_PARMS];
    unsigned short EEPROMBBPTuningParameters[NUM_EEPROM_BBP_TUNING_PARMS];
    BBP_TUNING_PARAMETERS_STRUC			BBPTuningParameters;
    unsigned char RfType;
};
#endif
