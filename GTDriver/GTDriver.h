/*
        
        File:			GTDriver.h
        Program:		GTDriver
		Author:			Michael Roßberg
						mick@binaervarianz.de
		Description:	GTDriver is a free driver for PrismGT based cards under OS X.
                
        This file is part of GTDriver.

    GTDriver is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    GTDriver is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with GTDriver; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
#include "WiFiControllerPCI.h"
#include "GTIDs.h"

typedef struct {
    gt_control_block    *cb;
    pageBlock_t         page;
    IOPhysicalAddress   dmaAddress;
} controlBlock;

class GTDriver : public WiFiControllerPCI {
    OSDeclareDefaultStructors(GTDriver)

public:
    virtual const OSString * newModelString() const;

    virtual bool startHardware();
    virtual bool initHardware();
    virtual bool freeHardware();
    virtual bool enableHardware();
    virtual bool disableHardware();
    virtual bool handleEjectionHardware();
    virtual bool getReadyForSleep();

    virtual bool handleInterrupt();
    virtual bool handleTimer();

    virtual IOReturn outputPacketHardware(struct mbuf * m);
    virtual IOReturn setHardwareAddressHardware(UInt8 *addr);

    virtual UInt32          getLinkSpeed();
    virtual bool            setSSID(UInt32 length, UInt8* ssid);
    virtual bool            setKey(UInt32 length, UInt8* key);
    virtual bool            setMode(wirelessMode mode);
    virtual bool            setFrequency(UInt32 frequency);
    virtual UInt32          getFrequency();

protected:
    bool        _uploadFirmware();
    bool        _initHW();
    bool        _updateMACAddress();
   
    //memory managment
    bool        _allocPacketForFragment(struct mbuf **packet, volatile gt_fragment *f);
    bool        _allocQueues();
    bool        _freePacketForFragment(struct mbuf **packet, volatile gt_fragment *f);
    bool        _freeTransmitQueues();
    bool        _freeQueues();
    
    //frame transport
    UInt32      _freeFragmentsInQueue(int queue);
    bool        _fillFragment(volatile gt_fragment *f, struct mbuf *packet, UInt16 flags = 0);
    IOReturn    _transmitInQueue(struct mbuf * m, int queue);
    int         _inQueue(int queue);
    
    //PIMFOR handling
    bool        _setStruc(UInt32 oid, void* data, UInt32 len, bool waitForResponse = false);
    bool        _setValue(UInt32 oid, UInt32 value, bool waitForResponse = false);
    bool        _getValue(UInt32 oid, UInt32 len = 4, bool waitForResponse = false);
    void        _fillPIMFOR(UInt32 operation, UInt32 oid, UInt32 length, pimforHeader *h);
    bool        _transmitPIM(UInt32 operation, UInt32 oid, UInt32 length, void* data, bool waitForResponse = false);
    bool        _parsePIMFOR(struct mbuf *m);
    
    
    inline UInt32 getRegister(int r, bool littleEndian = true) {
        if (_cardGone) return 0xFFFFFFFF;
        if (littleEndian)
            return OSReadLittleInt32((void*)_ioBase, r);
        else
            return OSReadBigInt32((void*)_ioBase, r);
    }
    
    inline void setRegister(int r, UInt32 v,
                            bool littleEndian = true, bool flush = true) {
        if (_cardGone) return;
        if (littleEndian)
            OSWriteLittleInt32((void*)_ioBase, r, v);
        else
            OSWriteBigInt32((void*)_ioBase, r, v);
	
        //for flushing?!
        if (flush) getRegister(GT_INT_EN_REG);
        OSSynchronizeIO();
    }    

    mutex_t                     *_mgmtMutex, *_dataMutex;
    controlBlock                _controlBlock;
    bool                        _initialized;
    bool                        _dozing;
    bool                        _doAsyncIO;
    bool                        _interruptBusy;
    bool                        _stalled;
    wirelessMode                _mode;

    UInt32                      _txDataLowPos, _txDataHighPos, _txDataMgmtPos;
    
    struct mbuf                 *_rxDataLow[CB_RX_QSIZE],   *_txDataLow[CB_TX_QSIZE], 
                                *_rxDataHigh[CB_RX_QSIZE],  *_txDataHigh[CB_TX_QSIZE],
                                *_rxDataMgmt[CB_MGMT_QSIZE],*_txDataMgmt[CB_MGMT_QSIZE];
                                
    UInt32                      _allocated, _freed, _rxAllocated, _rxFreed;
    volatile int                _interruptPoint, _lastIndex;
};
