/*
 *  RalinkJack.mm
 *  KisMAC
 *
 *  Created by Geoffrey Kruse on 5/28/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include "RalinkJack.h"

IOReturn RalinkJack::_init() {
    unsigned long			Index;
	unsigned char			buffer[22];
	unsigned short			temp;
	unsigned char			Value = 0xff;
	unsigned int			i;
    IOReturn                ret;
    
	NSLog(@"--> NICInitializeAsic");
    
	do
	{
		//NdisMSleep(1000);
		RTUSB_VendorRequest(kUSBOut,
                            0x1,
                            0x4,
                            0x1,
                            NULL,
                            0);
        
		RTUSBSingleWrite(0x308, 0xf0);//asked by MAX
            
        // Disable RX at first beginning. Before BulkInReceive, we will enable RX.
        RTUSBWriteMACRegister(TXRX_CSR2, 1);
        RTUSBWriteMACRegister(MAC_CSR13, 0x1111);//requested by Jerry
        RTUSBWriteMACRegister(MAC_CSR14, 0x1E11);
        RTUSBWriteMACRegister(MAC_CSR1, 3); // reset MAC state machine, requested by Kevin 2003-2-11
        RTUSBWriteMACRegister(MAC_CSR1, 0); // reset MAC state machine, requested by Kevin 2003-2-11
        RTUSBWriteMACRegister(TXRX_CSR5, 0x8C8D);
        RTUSBWriteMACRegister(TXRX_CSR6, 0x8B8A);
        RTUSBWriteMACRegister(TXRX_CSR7, 0x8687);
        RTUSBWriteMACRegister(TXRX_CSR8, 0x0085);
        RTUSBWriteMACRegister(TXRX_CSR21, 0xe78f);
        RTUSBWriteMACRegister(MAC_CSR9, 0xFF1D);
                
        i = 0;
        //check and see if asic has powered up
        RTUSBReadMACRegister(MAC_CSR17, &temp);
        while (((temp & 0x01e0 ) != 0x01e0) && (i < 50))
        {
            sleep(1);
            RTUSBReadMACRegister(MAC_CSR17, &temp);
                    
            i++;
        }
        if (i == 50)
        {
/*                    if (RTUSB_ResetDevice() == FALSE)
                    {
                        //RTMP_SET_FLAG( fRTMP_ADAPTER_REMOVE_IN_PROGRESS);
                        DBGPRINT(RT_DEBUG_TRACE, "<== NICInitializeAsic ERROR\n");
                        return;
                    }
                    else
                        continue;
                    */
        }
        
        //lets mess with the leds to verify we have control
        RTUSBWriteMACRegister(MAC_CSR20, 0x002);        //put led under software control
                                   
        RTUSBWriteMACRegister(MAC_CSR1, 4);        //host is ready to work
        RTUSBReadMACRegister(MAC_CSR0, &temp);          //read the asic version number
        if ( temp >= 3){
            RTUSBReadMACRegister(PHY_CSR2, &temp);
            RTUSBWriteMACRegister(PHY_CSR2, temp & 0xFFFD);		   
        }
        else
        {
            NSLog(@"LNA 3 mode\n");
            RTUSBWriteMACRegister(PHY_CSR2, 0x3002); // LNA 3 mode
        }
        //power save stuff
        RTUSBWriteMACRegister(MAC_CSR11, 2);
        RTUSBWriteMACRegister(MAC_CSR22, 0x53);
        RTUSBWriteMACRegister(MAC_CSR15, 0x01ee);
        RTUSBWriteMACRegister(MAC_CSR16, 0);
        RTUSBWriteMACRegister(MAC_CSR8, 0x0780);//steven:limit the maximum frame length
            
        RTUSBReadMACRegister(TXRX_CSR0, &temp);
        temp &= 0xe007;
        temp |= ((LENGTH_802_11 << 3) | (0x000f << 9));
        RTUSBWriteMACRegister(TXRX_CSR0, temp);
                    
        RTUSBWriteMACRegister(TXRX_CSR19, 0);
        RTUSBWriteMACRegister(MAC_CSR18, 0x5a);
                    
        //set RF_LE to low when standby
        RTUSBReadMACRegister(PHY_CSR4, &temp);
        RTUSBWriteMACRegister(PHY_CSR4, temp | 1);
        //NdisMSleep(100);//wait for PLL to become stable
                    
        i = 0;
        do
        {
            ret = RTUSBReadBBPRegister(BBP_Version, &Value);
            NSLog(@"Read BBP_Version Value = %d\n", Value);
            i++;
        }while (((Value == 0xff) || (Value == 0x00)) && (i < 50));
        if (i < 50)//BBP ready
        {
            break;
        }
                    /*
        else
        {
            if ( RTUSB_ResetDevice(pAdapter) == FALSE)
            {
                RTMP_SET_FLAG( fRTMP_ADAPTER_REMOVE_IN_PROGRESS);
                return;
            }
        }*/
	}while (1);
    
	// Initialize BBP register to default value
	for (Index = 0; Index < NUM_BBP_REG_PARMS; Index++)
	{
		i = 0;
		do
		{
			RTUSBReadMACRegister(PHY_CSR8, &temp);
			if (!(temp & BUSY))
				break;
			i++;
		}
		while (i < RETRY_LIMIT);
		
		RTUSBWriteMACRegister(PHY_CSR7, BBPRegTable[Index]);
    }
    
    
	// Initialize RF register to default value
	//AsicSwitchChannel(pAdapter, pAdapter->PortCfg.Channel);
	//AsicLockChannel(pAdapter, pAdapter->PortCfg.Channel);
    
	//RTUSBMultiRead(STA_CSR0, buffer, 22);
	UInt32 numBytesRead = sizeof(_recieveBuffer);
    (*_interface)->ReadPipeAsync(_interface, kInPipe, &_recieveBuffer, numBytesRead, (IOAsyncCallback1)_interruptRecieved, this);
	NSLog(@"<-- NICInitializeAsic\n");
        return kIOReturnSuccess;
}

IOReturn	RalinkJack::RTUSB_VendorRequest(UInt8 direction,
                        UInt8 bRequest, 
                        UInt16 wValue, 
                        UInt16 wIndex, 
                        void *pData,
                        UInt16 wLength) {
    
    IOReturn ret;
    char * buf;
    
	if (!_devicePresent)
	{
		NSLog(@"device not connected");
		return kIOReturnNoDevice;
	}
	else
	{
        IOUSBDevRequest theRequest;
        theRequest.bmRequestType = USBmakebmRequestType(direction, kUSBVendor, kUSBEndpoint);
        theRequest.bRequest = bRequest;
        theRequest.wValue = wValue; 
        theRequest.wIndex = wIndex; 
        theRequest.pData = pData;
        theRequest.wLength = wLength;
        
        ret = (*_interface)->ControlRequest(_interface, 0, &theRequest);
        
        //data is returned in the bus endian
        //we need to swap
        //this is going to be bad when we run on intel
       
        buf = (char*) malloc(sizeof(char) * wLength);
        swab(theRequest.pData, buf, wLength);
        memcpy(pData, buf,wLength);
        free(buf);
        
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
    
	Status = RTUSB_VendorRequest(kUSBOut,
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
    IOReturn ret;
    
	PhyCsr7.value				= 0;
	PhyCsr7.field.WriteControl	= 1;
	PhyCsr7.field.RegID 		= Id;
	ret = RTUSBWriteMACRegister(PHY_CSR7, PhyCsr7.value);
    
    if (ret!= kIOReturnSuccess) {
        NSLog(@"Error Reading the BBP Register.");
        return ret;
    }
	
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
    
	ret = RTUSBReadMACRegister(PHY_CSR7, (unsigned short*)&PhyCsr7);
	*pValue = (unsigned char)PhyCsr7.field.Data;
	
	return ret;
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
