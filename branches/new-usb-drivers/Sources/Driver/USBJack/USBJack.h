/*
        
        File:			USBIntersil.h
        Program:		KisMAC
	Author:			Michael Ro�berg
				mick@binaervarianz.de
	Description:		KisMAC is a wireless stumbler for MacOS X.
                
        This file is part of KisMAC.

    KisMAC is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    KisMAC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with KisMAC; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
#ifndef __USB_JACK
#define __USB_JACK

#include <Cocoa/Cocoa.h>
#include <IOKit/usb/IOUSBLib.h>
#include <pthread.h>
#include "../../Core/80211b.h"
#include <unistd.h>
#include "prism2.h"
#include "structs.h"

class USBJack {
public:
    virtual bool    startCapture(UInt16 channel);
    virtual bool    stopCapture();
    virtual bool    getChannel(UInt16* channel);
    virtual bool    getAllowedChannels(UInt16* channel);
    virtual bool    setChannel(UInt16 channel);
    bool    devicePresent();
    int     getDeviceType();
    
    WLFrame * receiveFrame();
    bool    sendFrame(UInt8* data);
    
    void    startMatching();
    virtual IOReturn    _init();
    USBJack();
    virtual ~USBJack();
    
protected:
    bool    run();
    bool    stopRun();
    
    int kInterruptPipe;
    int kOutPipe;
    int kInPipe; 
    
    enum  deviceTypes {
        intersil = 1,
        zydas,
        ralink,
		rt73
    } deviceType; 

    IOReturn    _doCommand(enum WLCommandCode cmd, UInt16 param0, UInt16 param1 = 0, UInt16 param2 = 0);
    IOReturn    _doCommandNoWait(enum WLCommandCode cmd, UInt16 param0, UInt16 param1 = 0, UInt16 param2 = 0);
#if BYTE_ORDER == BIG_ENDIAN
        IOReturn    _getRecord(UInt16 rid, void* buf, UInt32* n, bool swapBytes = true);
        IOReturn    _setRecord(UInt16 rid, const void* buf, UInt32 n, bool swapBytes = true);
#else 
        IOReturn    _getRecord(UInt16 rid, void* buf, UInt32* n, bool swapBytes = false); 
        IOReturn    _setRecord(UInt16 rid, const void* buf, UInt32 n, bool swapBytes = false); 
#endif
    IOReturn    _getValue(UInt16 rid, UInt16* v);
    IOReturn    _setValue(UInt16 rid, UInt16 v);
    IOReturn    _sendFrame(UInt8* data, IOByteCount size);
    
    IOReturn    _getHardwareAddress(struct WLHardwareAddress* addr);
    IOReturn    _getIdentity(WLIdentity* wli);
    int         _getFirmwareType();
    IOReturn    _disable();
    IOReturn    _enable();
    virtual IOReturn    _reset();
    
    inline void        _lockDevice();
    inline void        _unlockDevice();
    inline IOReturn    _writeWaitForResponse(UInt32 size);
    
    IOReturn    _configureAnchorDevice(IOUSBDeviceInterface **dev);
    IOReturn    _findInterfaces(IOUSBDeviceInterface **dev);
    
    bool                _attachDevice();
    static void         _addDevice(void *refCon, io_iterator_t iterator);
    static void         _handleDeviceRemoval(void *refCon, io_iterator_t iterator);
    static void         _interruptRecieved(void *refCon, IOReturn result, int len);
    virtual bool        _massagePacket(int len);
    virtual int         WriteTxDescriptor(WLFrame * theFrame);
    static void         _runCFRunLoop(USBJack* me);
  
  // static IOUSBDeviceInterface **_foundDevices[10];
  //  static int         _deviceType[10];
  //  static int         _numDevices;

    SInt32                      _vendorID;
    SInt32                      _productID;
    
    bool                        _devicePresent;
    bool                        _deviceInit;
    bool                        _stayUp;
    bool                        _isSending;
    bool                        _isEnabled;
    SInt16                      _firmwareType;
    
    CFRunLoopRef                _runLoop;
    UInt16                      _channel;
    IONotificationPortRef	_notifyPort;
    CFRunLoopSourceRef		_runLoopSource;
    io_iterator_t		_deviceAddedIter;
    io_iterator_t		_deviceRemovedIter;
    IOUSBInterfaceInterface**   _interface;
    IOUSBDeviceInterface**      _dev;           //save this so we can't use the same device twice!
    union _usbout               _outputBuffer;
    union _usbin                _inputBuffer;
    union _usbin                _recieveBuffer;
    UInt8                       _frameBuffer[3000];
    UInt16                      _frameSize;
    
    pthread_mutex_t             _wait_mutex;
    pthread_cond_t              _wait_cond;
    pthread_mutex_t             _recv_mutex;
    pthread_cond_t              _recv_cond;
};


#endif