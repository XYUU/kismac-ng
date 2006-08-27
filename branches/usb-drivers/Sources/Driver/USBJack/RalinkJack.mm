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
                        UInt16 wLength, 
                        void *pData, 
                        UInt32 wLenDone ) {
    
    int ret;
    
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
        theRequest->wLength = wLength; 
        theRequest->pData = pData;
        theRequest->wLenDone = wLenDone; 
        
        ret = (*_interface)->ControlRequest(_interface, 0, theRequest);
        
    }
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
