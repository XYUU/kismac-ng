//
//  IntersilJack.mm
//  KisMAC
//
//  Created by Geoffrey Kruse on 5/1/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "IntersilJack.h"

bool IntersilJack::startCapture(UInt16 channel) {
    if (!_devicePresent) return false;
    if (!_deviceInit) return false;
    
    if ((!_isEnabled) && (_disable() != kIOReturnSuccess)) {
        NSLog(@"IntersilJack::startCapture: Couldn't disable card\n");
        return false;
    }
    
    if (setChannel(channel) == false) {
        NSLog(@"IntersilJack::startCapture: setChannel(%d) failed - resetting...\n",
              channel);
		_reset();
        return false;
    }
    
    if (_doCommand(wlcMonitorOn, 0) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::startCapture: _doCommand(wlcMonitorOn) failed\n");
        return false;
    }
    
    if (_enable() != kIOReturnSuccess) {
        NSLog(@"IntersilJack::startCapture: Couldn't enable card\n");
        return false;
    }
    
    _channel = channel;
    return true;
}

bool IntersilJack::stopCapture() {
_channel = 0;

if (!_devicePresent) return false;
if (!_deviceInit) return false;

if (_doCommand(wlcMonitorOff, 0) != kIOReturnSuccess) {
    NSLog(@"::stopCapture: _doCommand(wlcMonitorOff) failed\n");
    return false;
}

return true;
}

bool IntersilJack::getChannel(UInt16* channel) {
    if (!_devicePresent) return false;
    if (!_deviceInit) return false;
    
    if (_getValue(0xFDC1, channel) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::getChannel: getValue error\n");
        return false;
    }
    
    _channel = *channel;
    return true;
}

bool IntersilJack::getAllowedChannels(UInt16* channels) {
    if (!_devicePresent) return false;
    if (!_deviceInit) return false;
    
    if (_getValue(0xFD10, channels) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::getAllowedChannels: getValue error\n");
        return false;
    }
    
    return true;
}

bool IntersilJack::setChannel(UInt16 channel) {
    if (!_devicePresent) return false;
    if (!_deviceInit) return false;
    
    if (_setValue(0xFC03, channel) != kIOReturnSuccess) {
        usleep(10000);
        if (_setValue(0xFC03, channel) != kIOReturnSuccess) {
            NSLog(@"IntersilJack::setChannel: setValue error\n");
            return false;
        }
    }
    
    if (_isEnabled) {
        if (_disable() != kIOReturnSuccess) {
            NSLog(@"IntersilJack::setChannel: Couldn't disable card\n");
            return false;
        }
        if (_enable() != kIOReturnSuccess) {
            NSLog(@"IntersilJack::setChannel: Couldn't enable card\n");
            return false;
        }
    }
    
    _channel = channel;
    return true;
}

IOReturn IntersilJack::_init() {
    WLIdentity ident;
    WLHardwareAddress macAddr;
    int i; 
    
    if(!_attachDevice()){
        NSLog(@"Device could not be opened");
        return kIOReturnNoDevice;
    }
    
    _firmwareType = -1;
    
    for (i = 0; i< wlResetTries; i++) {
        if (_reset() == kIOReturnSuccess) break;
        if (!_devicePresent) return kIOReturnError;
    }
    
    /*
     * Get firmware vendor and version
     */
    
    if (_getIdentity(&ident) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::_init: Couldn't read card identity\n");
        return kIOReturnError;
    }
    
    NSLog(@"IntersilJack: Firmware vendor %d, variant %d, version %d.%d\n", ident.vendor, ident.variant, ident.major, ident.minor);
    
    if (_getHardwareAddress(&macAddr) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::_init: Couldn't read MAC address\n");
        return kIOReturnError;
    }
    
    _deviceInit = true;
    
    return kIOReturnSuccess;
}

IOReturn IntersilJack::_reset() {
    int i;
    
    if (_doCommand(wlcInit, 0) != kIOReturnSuccess) {
        NSLog(@"IntersilJack::_reset: _doCommand(wlcInit, 0) failed\n");
        return kIOReturnError;
    }
    
    usleep(100000); // give it a sec to reset
    
    for (i = 0; i < wlTimeout; i++) {
        _firmwareType = _getFirmwareType();
        if (_firmwareType != -1) break;
    }
    
    for (i = 0; i < wlTimeout; i++) {
        if (_setValue(0xFC00, (_firmwareType == WI_LUCENT) ? 0x3 : 0x5) == kIOReturnSuccess) break;
    }
    
    if (_firmwareType == WI_INTERSIL) {
        _setValue(0xFC06, 1); //syscale
        _setValue(0xFC07, 2304); //max data len
        _setValue(0xFC09, 0); //pm off!
        _setValue(0xFC84, 3); //default tx rate
        _setValue(0xFC85, 0); //promiscous mode
        _setValue(0xFC2A, 1); //auth type
        _setValue(0xFC2D, 1); //roaming by firmware
		_setValue(0xFC28, 0x90); //set wep ignore
    }
    
    if (i==wlTimeout) {
        NSLog(@"IntersilJack::_reset: could not set port type\n");
        return kIOReturnError;
    }
    
    /*
     * Set list of interesting events
     */
    //_interrupts = wleRx;  //| wleTx | wleTxExc | wleAlloc | wleInfo | wleInfDrop | wleCmd | wleWTErr | wleTick;
    
    _enable();
    _isSending = false;
    
    return kIOReturnSuccess;
}

bool IntersilJack::sendFrame(UInt8* data, int size) {
    WLFrame *frameDescriptor;
    UInt8 aData[2364];
    IOByteCount pktsize;
    int descriptorLength;
    WLIEEEFrame * wifiFrame;
    //we have an inFrame and an outFrame
    //this function is a transformation between the two
    //copy the wlframe to the tx buff
    //we will redo part off_t this //todo fixme!!
    memcpy(aData, data, sizeof(WLFrame));
    
    //set pointers to sectons of frame
    frameDescriptor = (WLFrame*)aData;
    pktsize = frameDescriptor->dataLen + sizeof(WLFrame) - sizeof(WLPrismHeader);
    
    //convert prism header into device specific header 
    //returns the length of the device specific header
    //note frame descriptor = txbuff
    descriptorLength = WriteTxDescriptor(frameDescriptor);
    
    //copy the 802.11 frame to the right  place
    memcpy(aData + descriptorLength, data + sizeof(WLPrismHeader),  pktsize);
    wifiFrame = (WLIEEEFrame*)(aData + descriptorLength);
    
    switch(wifiFrame->frameControl & 0x0c) {
        case 0x08:
        case 0x00:
            pktsize = wifiFrame->dataLen;
            if ((pktsize + descriptorLength) > 2364)
                return kIOReturnBadArgument;
            wifiFrame->dataLen=NSSwapHostShortToLittle(wifiFrame->dataLen);
            break;
        case 0x04:
            pktsize = 0;
            wifiFrame->dataLen = 0;
            break;
        default:
            return kIOReturnBadArgument;
    }
    
    //send the frame
    if (_sendFrame(aData, pktsize + descriptorLength) != kIOReturnSuccess)
        return NO;
    
    return YES;
}

int IntersilJack::WriteTxDescriptor(WLFrame * theFrame){
    theFrame->txControl=NSSwapHostShortToLittle(0x08 | _TX_RETRYSTRAT_SET(3)| _TX_CFPOLL_SET(1) | _TX_TXEX_SET(0) | _TX_TXOK_SET(0) | _TX_MACPORT_SET(0));
    theFrame->rate = 0x6e;	//11 MBit/s
    theFrame->tx_rate = 0x6e;	//11 MBit/s 
    return sizeof(WLPrismHeader);
}

IntersilJack::IntersilJack() {
}

IntersilJack::~IntersilJack() {
    /*
    stopRun();
    _interface = NULL;
    
    pthread_mutex_destroy(&_wait_mutex);
    pthread_cond_destroy(&_wait_cond);
    pthread_mutex_destroy(&_recv_mutex);
    pthread_cond_destroy(&_recv_cond);
*/
}

