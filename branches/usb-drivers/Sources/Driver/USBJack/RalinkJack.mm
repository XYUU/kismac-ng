/*
 *  RalinkJack.mm
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include "RalinkJack.h"

IOReturn	RalinkJack::RTUSB_VendorRequest(UInt8 direction,
                        UInt8 bRequest, 
                        UInt16 wValue, 
                        UInt16 wIndex, 
                        void *pData,
                        UInt16 wLength) {
    
    IOReturn ret;
    
	if (!_devicePresent)
	{
		NSLog(@"device not connected");
		return kIOReturnNoDevice;
	}
	else
	{
        IOUSBDevRequest * theRequest;
        theRequest->bmRequestType = USBmakebmRequestType(direction, kUSBVendor, kUSBEndpoint);
        theRequest->bRequest = bRequest;
        theRequest->wValue = wValue; 
        theRequest->wIndex = wIndex; 
        theRequest->pData = pData;
        theRequest->wLength = wLength;
        
        ret = (*_interface)->ControlRequest(_interface, 0, theRequest);
        
        if (theRequest->wLenDone < wLength) {
            NSLog(@"WTF, we didn't seem to write the whole request?");
        }
        
    }
	return ret;    
}

IOReturn RalinkJack::RTUSBSingleRead(unsigned short Offset,
                                     unsigned short * pValue)
{
	IOReturn	Status;
    
	Status = RTUSB_VendorRequest(kUSBIn,
                                 0x3,
                                 0,
                                 Offset,
                                 pValue,
                                 2);
	return Status;
}

IOReturn	RalinkJack::RTUSBSingleWrite(unsigned short	Offset,
                                         unsigned short Value)
{
	IOReturn	Status;
	
	Status = RTUSB_VendorRequest(
                                 kUSBOut,
                                 0x2,
                                 Value,
                                 Offset,
                                 NULL,
                                 0);	
	return Status;
}

IOReturn RalinkJack::RTUSBWriteMACRegister(unsigned short Offset,
                                  unsigned short Value)
{
	IOReturn Status;
	if (Offset == TXRX_CSR2)
        NSLog(@" !!!!!set Rx control = %x\n", Value);
    
	Status = RTUSB_VendorRequest(
                                 kUSBOut,
                                 0x2,
                                 Value,
                                 Offset + 0x400,
                                 NULL,
                                 0);	
	return Status;
}

IOReturn	RalinkJack::RTUSBReadMACRegister(unsigned short Offset,
                                             unsigned short * pValue)
{
	IOReturn Status;
	
	Status = RTUSB_VendorRequest(kUSBIn,
                                 0x3,
                                 0,
                                 Offset + 0x400,
                                 pValue,
                                 2);	
	return Status;
}

IOReturn	RalinkJack::RTUSBReadBBPRegister(unsigned char Id,
                                 unsigned char * pValue)
{
	PHY_CSR7_STRUC	PhyCsr7;
	unsigned short			temp;
	unsigned int			i = 0;
    
	PhyCsr7.value				= 0;
	PhyCsr7.field.WriteControl	= 1;
	PhyCsr7.field.RegID 		= Id;
	RTUSBWriteMACRegister(PHY_CSR7, PhyCsr7.value);
	
	do
	{
		RTUSBReadMACRegister(PHY_CSR8, &temp);
		if (!(temp & BUSY))
			break;
		i++;
	}
	while (i < RETRY_LIMIT);
    
	if (i == RETRY_LIMIT)
	{
		NSLog(@"Retry count exhausted or device removed!!!\n");
		return kIOReturnNotResponding;
	}
    
	RTUSBReadMACRegister(PHY_CSR7, (unsigned short *)&PhyCsr7);
	*pValue = (unsigned char)PhyCsr7.field.Data;
	
	return kIOReturnSuccess;
}


RalinkJack::RalinkJack() {
    _isEnabled = false;
    _deviceInit = false;
    _devicePresent = false;
    
    _interface = NULL;
    _runLoopSource = NULL;
    _runLoop = NULL;
    _intLoop = NULL;
    _channel = 3;
    _frameSize = 0;
    _notifyPort = NULL;
    
    pthread_mutex_init(&_wait_mutex, NULL);
    pthread_cond_init (&_wait_cond, NULL);
    pthread_mutex_init(&_recv_mutex, NULL);
    pthread_cond_init (&_recv_cond, NULL);
    
    run();
    
    while (_runLoop==NULL || _intLoop==NULL)
        usleep(100);
}

RalinkJack::~RalinkJack() {
    stopRun();
    _interface = NULL;
    _frameSize = 0;
    
    pthread_mutex_destroy(&_wait_mutex);
    pthread_cond_destroy(&_wait_cond);
    pthread_mutex_destroy(&_recv_mutex);
    pthread_cond_destroy(&_recv_cond);
}
