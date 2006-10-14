/*
 *  RT73Jack.h
 *  KisMAC
 *
 *  Created by Vincent Borrel on 10/11/06.
 *
 */
#ifndef	__RT73JACK_H__
#define	__RT73JACK_H__

#import <Cocoa/Cocoa.h>
#import "USBJack.h"
#include "RT73.h"

class RT73Jack: public USBJack
{
public:
    
    RT73Jack();
    ~RT73Jack();
    
    IOReturn _init();
    
    IOReturn	RTUSB_VendorRequest(
                                    UInt8 direction,
                                    UInt8 bRequest, 
                                    UInt16 wValue, 
                                    UInt16 wIndex, 
                                    void *pData,
                                    UInt16 wLength,
                                    bool swap);
    
    IOReturn	RTUSBMultiRead(
                               unsigned short	Offset,
                               unsigned char	*pData,
                               unsigned short	length);
    
    IOReturn	RTUSBMultiWrite(
                                unsigned short	Offset,
                                unsigned char	*pData,
                                unsigned short 	length);
    
	IOReturn	RTUSBFirmwareRun();
    
	IOReturn	RTUSBWriteHWMACAddress();
    
	IOReturn	RTUSBSetLED(
                            MCU_LEDCS_STRUC	LedStatus,
                            unsigned short	LedIndicatorStrength);
    
	IOReturn	RTMPSetLED(
                           unsigned char	LEDStatus);
    
    IOReturn    RTUSBWriteMACRegister(
                                      unsigned short	Offset,
                                      unsigned long	Value);
    
    IOReturn	RTUSBReadMACRegister(
                                     unsigned short	Offset,
                                     unsigned long	*pValue);
    
    IOReturn	RTUSBReadBBPRegister(
                                     unsigned char	Id,
                                     unsigned char	*pValue);
    
    IOReturn	RTUSBWriteBBPRegister(
                                      unsigned char	Id,
                                      unsigned char	Value);
    
    IOReturn	RTUSBWriteRFRegister(
                                     unsigned long	Value);
    
    IOReturn	RTUSBReadEEPROM(
                                unsigned short	Offset,
                                unsigned char	*pData,
                                unsigned short	length);
    
	IOReturn	NICInitializeAsic();
    
	IOReturn	NICLoadFirmware();
    
    
    void	NICReadEEPROMParameters();
    void	NICInitAsicFromEEPROM();
    
    bool setChannel(UInt16 channel);
    bool getAllowedChannels(UInt16* channels);
    bool startCapture(UInt16 channel);
    bool stopCapture();
    
    bool _massagePacket(int len);
    
private:
        
        //    int temp;
        //    unsigned short	EEPROMDefaultValue[NUM_EEPROM_BBP_PARMS];
        //    unsigned short	EEPROMBBPTuningParameters[NUM_EEPROM_BBP_TUNING_PARMS];
        //    RT73_BBP_TUNING_PARAMETERS_STRUC	RT73_BBPTuningParameters;
        //    unsigned char	RfType;
        
        bool	NICInitialized;
    
    unsigned char	PermanentAddress[ETH_LENGTH_OF_ADDRESS];
	CHANNEL_TX_POWER	TxPower[MAX_NUM_OF_CHANNELS];	// Store Tx power value for all channels.
	unsigned long	EepromVersion;	// byte 0: version, byte 1: revision, byte 2~3: unused
	unsigned short	EEPROMDefaultValue[NUM_EEPROM_BBP_PARMS];
	bool 	bAutoTxAgcA;				// Enable driver auto Tx Agc control
	unsigned char		TssiRefA;					// Store Tssi reference value as 25 tempature.	
	unsigned char		TssiPlusBoundaryA[5];		// Tssi boundary for increase Tx power to compensate.
	unsigned char		TssiMinusBoundaryA[5];		// Tssi boundary for decrease Tx power to compensate.
	unsigned char		TxAgcStepA;					// Store Tx TSSI delta increment / decrement value
	char		TxAgcCompensateA;			// Store the compensation (TxAgcStep * (idx-1))
	bool 	bAutoTxAgcG;				// Enable driver auto Tx Agc control
	unsigned char		TssiRefG;					// Store Tssi reference value as 25 tempature.	
	unsigned char		TssiPlusBoundaryG[5];		// Tssi boundary for increase Tx power to compensate.
	unsigned char		TssiMinusBoundaryG[5];		// Tssi boundary for decrease Tx power to compensate.
	unsigned char		TxAgcStepG;					// Store Tx TSSI delta increment / decrement value
	char	TxAgcCompensateG;			// Store the compensation (TxAgcStep * (idx-1))
	unsigned char					BbpRssiToDbmDelta;
	unsigned char	RFProgSeq;
	unsigned long					RfFreqOffset;	// Frequency offset for channel switching
	char	BGRssiOffset1;				// Store B/G RSSI#1 Offset value on EEPROM 0x9Ah
	char	BGRssiOffset2;				// Store B/G RSSI#2 Offset value 
	char	ARssiOffset1;				// Store A RSSI#1 Offset value on EEPROM 0x9Ch
	char	ARssiOffset2;
    EEPROM_TXPOWER_DELTA_STRUC  TxPowerDeltaConfig;				// Compensate the Tx power BBP94 with this configurate value
	unsigned char					RfIcType;		// RFIC_xxx
	unsigned long					ExtraInfo;				// Extra information for displaying status
    
	RTMP_RF_REGS			LatchRfRegs;	// latch th latest RF programming value since RF IC doesn't support READ
    
    
	MCU_LEDCS_STRUC	LedCntl;
	unsigned short	LedIndicatorStrength;
};
#endif