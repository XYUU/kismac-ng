/*
        
        File:			GTDriver.cpp
        Program:		GTDriver
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		GTDriver is a free driver for PrismGT based cards under OS X.
                
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

#include "GTDriver.h"
#include "GTFirmware.h"

extern "C" {
#include <sys/param.h>
#include <sys/mbuf.h>
#include <string.h>
}

#define GT_WRITEDELAY 1
#define abs(x)  ((x < 0) ? -x : x)

#define super WiFiControllerPCI
OSDefineMetaClassAndStructors(GTDriver, WiFiControllerPCI)

const OSString* GTDriver::newModelString() const {
    return OSString::withCString("Prism GT card");
}

#pragma mark -

bool GTDriver::startHardware() {
    int i;
    WLEnter();

    _mgmtMutex = mutex_alloc(ETAP_NO_TRACE);
    _dataMutex = mutex_alloc(ETAP_NO_TRACE);
    _interruptBusy = false;
    _stalled = false;
    
    if (!_allocQueues()) return false;
    if (!initHardware()) return false;

    //wait for intialization
    for(i = 0; i < 1000; i++) {
        if (_initialized) break;
        IOSleep(1);
    }
    
    if (!_updateMACAddress()) return false;
    if (_enabledForNetif) enableHardware();
    else disableHardware();
    
    WLExit();

    return true;
}

bool GTDriver::initHardware() {
    WLEnter();
    
    _dozing = false;
 
    if (!_uploadFirmware()) return false;
    if (!_initHW()) return false;
    
    WLExit();
    return true;
};

bool GTDriver::freeHardware() {
    WLEnter();
    _initialized = false;
    
    disableHardware();
    _freeQueues();

    mutex_free(_mgmtMutex);
    mutex_free(_dataMutex);
    WLExit();
    return true;
}

bool GTDriver::enableHardware() {
    WLEnter();
    
    //_setValue(OID_CONFIG, INL_CONFIG_MANUALRUN);
    _setValue(OID_MODE, INL_MODE_CLIENT);
    _setValue(OID_MAXFRAMEBURST, DOT11_MAXFRAMEBURST_MIXED_SAFE);
    _setValue(OID_AUTHENABLE, DOT11_AUTH_BOTH);
    
    UInt8 data[4];
    memset(data, 0xFF, 2);
    _setStruc(OID_SCAN, &data, 2);
    
    WLExit();
    
    return true;
}

bool GTDriver::disableHardware() {
    //disable the card
    WLEnter();
    
    UInt8 data[4];
    memset(data, 0x0, 2);
    _setStruc(OID_SCAN, &data, 2);

    _setValue(OID_MODE, INL_MODE_NONE);
    WLExit();
    return true;
}

bool GTDriver::getReadyForSleep() {
    WLEnter();
    
    setRegister(GT_INT_EN_REG, 0);
    setRegister(GT_CTRL_BLOCK, 0);
    _txDataLowPos = _txDataHighPos = _txDataMgmtPos = 0;
    _lastIndex = 0;
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_LOW] = OSSwapHostToLittleInt32(CB_RX_QSIZE);
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_HIGH] = OSSwapHostToLittleInt32(CB_RX_QSIZE);
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_MGMT] = OSSwapHostToLittleInt32(CB_MGMT_QSIZE);

    _freeTransmitQueues();
    
    WLExit();
    return true;
}

bool GTDriver::handleEjectionHardware() { 
    bool mblocked, dblocked;
    
    if (!_controlBlock.cb) return true;
    
    WLLogDebug(
      "CB drv Qs: [%d][%d][%d][%d][%d][%d]",
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[0]),
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[1]),
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[2]),
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[3]),
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[4]),
      OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[5])
    );

    WLLogDebug(
      "CB dev Qs: [%d][%d][%d][%d][%d][%d]",
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[0]),
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[1]),
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[2]),
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[3]),
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[4]),
      OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[5])
    );
    
    mblocked = mutex_try(_mgmtMutex);
    dblocked = mutex_try(_dataMutex);
    if (mblocked) mutex_unlock(_mgmtMutex);
    if (dblocked) mutex_unlock(_dataMutex);
    
    WLLogDebug(
        "Allocated Packets: %d Freed Packets: %d Allocated RxPackets: %d Freed RxPackets: %d dataLowPos: %d dataHighPos: %d dataMgmtPos: %d mgmtMutex: %s dataMutex: %s interrupted: %s initalized: %s interruptPoint:%d lastIndex:%d",
        (int)_allocated, (int)_freed, (int)_rxAllocated, (int)_rxFreed, 
        (int)_txDataLowPos, (int)_txDataHighPos, (int)_txDataMgmtPos,
        (!mblocked ? "locked" : "not locked"), (!dblocked ? "locked" : "not locked"),
        (_interruptBusy ? "running" : "not running"),
        (_initialized ? "init" : "not init"),
        _interruptPoint, (int)_lastIndex
    );
    
    return true; 
}

typedef struct {
	UInt16 unk0;		/* = 0x0000 */
	UInt16 length;		/* = 0x1400 */
	UInt32 clock;		/* 1MHz clock */
	volatile UInt8 flags;
	UInt8 unk1;
	volatile UInt8 rate;
	UInt8 unk2;
	volatile UInt16 freq;
	UInt16 unk3;
	volatile UInt8 rssi;
	UInt8 padding[3];
} rfmonHeader __attribute__ ((packed));

bool GTDriver::handleInterrupt() {
    UInt32 ident;
    rfmonHeader *rfHead;
    
    //WLEnter();
    
    if (getRegister(GT_CTRL_STAT_REG) & GT_CTRL_STAT_SLEEPMODE) {
        WLLogDebug("Got an interrupt from a sleeping device!");
        return false;
    }
    
    ident = getRegister(GT_INT_IDENT_REG) & GT_INT_SOURCES;
    if (ident==0) {
        WLLogWarn("Got an interrupt which cannot be handled!");
        return false;
    }
    
    //acknowledge the interrupt
    setRegister(GT_INT_ACK_REG, ident);
        
    _dozing = false;
    if (ident & GT_INT_IDENT_INIT) {
        _currentState = stateDisconnected;
        _initialized = true;
    }
    if (ident & GT_INT_IDENT_WAKEUP) {
        setRegister(GT_DEV_INT_REG, GT_DEV_INT_UPDATE);
        _dozing = false;
    }
    if ((ident & GT_INT_IDENT_UPDATE) != 0 && _initialized) {
        
        SInt32 count;
        bool updated = false;
        
        for (count = _inQueue(QUEUE_RX_MGMT); count > 0; count--) {
            updated = true;
            //because we fill our buffers completly, we can get the first message in this way...
            UInt32 frag = OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[QUEUE_RX_MGMT]);
            UInt32 fragMod = frag % CB_MGMT_QSIZE;
            
            _parsePIMFOR(_rxDataMgmt[fragMod]);
            
            _allocPacketForFragment(&_rxDataMgmt[fragMod], &_controlBlock.cb->rx_data_mgmt[fragMod]);
            _controlBlock.cb->driver_curr_frag[QUEUE_RX_MGMT] = OSSwapHostToLittleInt32(++frag);
        }

        for (count = _inQueue(QUEUE_RX_HIGH); count > 0; count--) {
            updated = true;
            //because we fill our buffers completly, we can get the first message in this way...
            UInt32 frag = OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[QUEUE_RX_HIGH]);
            UInt32 fragMod = frag % CB_RX_QSIZE;
            
            if (_enabledForNetif) {
                m_adj(_rxDataHigh[fragMod], 2);
                _netif->inputPacket(_rxDataHigh[fragMod], OSSwapLittleToHostInt16(_controlBlock.cb->rx_data_high[fragMod].size),
                                   IONetworkInterface::kInputOptionQueuePacket);
                _netStats->inputPackets++;
                _rxFreed++;
            } else {
                freePacket(_rxDataHigh[fragMod]);
                _rxFreed++;
            }
            
            _allocPacketForFragment(&_rxDataHigh[fragMod], &_controlBlock.cb->rx_data_high[fragMod]);
            _controlBlock.cb->driver_curr_frag[QUEUE_RX_HIGH] = OSSwapHostToLittleInt32(++frag);
        }
                
        for (count = _inQueue(QUEUE_RX_LOW); count > 0; count--) {
            updated = true;
            //because we fill our buffers completly, we can get the first message in this way...
            UInt32 frag = OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[QUEUE_RX_LOW]);
            UInt32 fragMod = frag % CB_RX_QSIZE;
            
            if (_mode == modeMonitor) {
                rfHead = mtod(_rxDataLow[fragMod], rfmonHeader*);
                if ((rfHead->flags & 0x01) == 0x0) {
                    if (!_packetQueue->enqueue(mtod(_rxDataLow[fragMod], void*), OSSwapLittleToHostInt16(_controlBlock.cb->rx_data_low[fragMod].size))) WLLogInfo("packet queue overflow");
                } else WLLogErr("dropping packet");
                
                freePacket(_rxDataLow[fragMod]);                
            } else if (_enabledForNetif) {
                m_adj(_rxDataLow[fragMod], 2);
                _netif->inputPacket(_rxDataLow[fragMod], OSSwapLittleToHostInt16(_controlBlock.cb->rx_data_low[fragMod].size),
                                   IONetworkInterface::kInputOptionQueuePacket);
                _netStats->inputPackets++;
            } else {
                freePacket(_rxDataLow[fragMod]);
            }
            
            _allocPacketForFragment(&_rxDataLow[fragMod], &_controlBlock.cb->rx_data_low[fragMod]);
            _controlBlock.cb->driver_curr_frag[QUEUE_RX_LOW] = OSSwapHostToLittleInt32(++frag);
        }
        
        _freeTransmitQueues();

        if (updated) { //tickle the device
            setRegister(GT_DEV_INT_REG, GT_DEV_INT_UPDATE);
            if (_enabledForNetif) _netif->flushInputQueue();
        }
    }
    if (ident & GT_INT_IDENT_SLEEP) {
        UInt32 i;
        for (i = QUEUE_RX_LOW; i <= QUEUE_TX_MGMT; i++) {
            if (_inQueue(i)) break;
        }
        if (i > QUEUE_TX_MGMT) {
            WLLogInfo("Going to sleep");
            setRegister(GT_DEV_INT_REG, GT_DEV_INT_SLEEP);
            _dozing = true;
        }
    }
    //WLExit();

    return true;
}

bool GTDriver::handleTimer() {
    if (_linkSpeed) {
        _getValue(OID_LINKSTATE);
        _getValue(OID_BSSID, 6);
        //_getValue(OID_TXPOWER);
    } else {
        WLLogDebug("NO Link present");
    }
    _getValue(OID_BSS_LIST, sizeof(objBSSList));
    return true;
}

IOReturn GTDriver::outputPacketHardware(struct mbuf * m) {
    return _transmitInQueue(m, QUEUE_TX_LOW);
}

IOReturn GTDriver::setHardwareAddressHardware(UInt8 *addr) { 
    return _setStruc(OID_MACADDRESS, addr, 6) ? kIOReturnSuccess : kIOReturnError; 
}

#pragma mark -

UInt32 GTDriver::getLinkSpeed() { 
    return _linkSpeed; 
}

bool GTDriver::setSSID(UInt32 length, UInt8* ssid) { 
    UInt8 data[34];
 
    super::setSSID(length, ssid);
       
    memset(data, 0, 34);
    memcpy(&data[1], _ssid, _ssidLength);
    data[0] = _ssidLength;
    
    return _setStruc(OID_SSID, data, 34);
}

bool GTDriver::setKey(UInt32 length, UInt8* key) { 
    keyObject k;
    
    length = length > 32 ? 32 : length;
    memset(&k, 0, sizeof(k));
    memcpy(&k.key, key, length);
    k.len = length;
    
    _setStruc(OID_DEFKEY1, &k, sizeof(k));
    _setValue(OID_DEFKEYID, 0);
    _setValue(OID_PRIVACYINVOKED, length ? 1 : 0);
    
    WLLogInfo("Setting hex key with length: %d", (int)length);
    
    return true;
}

UInt32 GTDriver::getFrequency() { 
    _getValue(OID_FREQUENCY, 4, true);
    return _currentFrequency; 
};

bool GTDriver::setFrequency(UInt32 frequency) { 
    _setValue(OID_FREQUENCY, frequency, true);
    _getValue(OID_FREQUENCY, 4, true);
    return frequency == _currentFrequency;
}

bool GTDriver::setMode(wirelessMode mode) { 
    switch(mode) {
        case modeClient:
            _setValue(OID_CONFIG, INL_CONFIG_NOTHING);
            _setValue(OID_MODE, INL_MODE_CLIENT);
            _setValue(OID_BSSTYPE, DOT11_BSSTYPE_INFRA);
            break;
        case modeIBSS:
            _setValue(OID_CONFIG, INL_CONFIG_NOTHING);
            _setValue(OID_MODE, INL_MODE_CLIENT);
            _setValue(OID_BSSTYPE, DOT11_BSSTYPE_IBSS);
            break;
        case modeMonitor:
            WLLogCrit("Enabling monitor mode!");
            _setValue(OID_CONFIG, INL_CONFIG_RXANNEX);
            _setValue(OID_MODE, INL_MODE_PROMISCUOUS);
            break;
        default:
            WLLogErr("Unsupported mode %d", mode);
            return false;
    }
    _mode = mode;
    return true;
}

#pragma mark -

bool GTDriver::_updateMACAddress() {
    for (int i = 0; i < 10; i++) //try a couple of times
        if (_getValue(OID_MACADDRESS, 6, true)) return true;

    return false;
}

bool GTDriver::_uploadFirmware() {
    UInt32 statReg;
    UInt32 firmReg, bcount, length, temp;
    const UInt8 *buf;
    
    WLEnter();
    
    _initialized = false;
    
    /* clear the RAMBoot and the Reset bit */
    statReg = getRegister(GT_CTRL_STAT_REG);
    statReg &= ~GT_CTRL_STAT_RESET;
    statReg &= ~GT_CTRL_STAT_RAMBOOT;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    
    /* set the Reset bit without reading the register ! */
    statReg |= GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    
    /* clear the Reset bit */
    statReg &= ~GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IOSleep(50);
    
    // upload
    // prepare the Direct Memory Base register
    firmReg = GT_DEV_FIRMWARE_ADDRESS;

    // enter a loop which reads data blocks from the file and writes them
    // to the Direct Memory Windows
    buf = gtFirmware;
    bcount = gtFirmwareSize;

    do {
        // set the cards base address for writting the data
        setRegister(GT_DIR_MEM_BASE_REG, firmReg);
        IODelay(GT_WRITEDELAY);

        WLLogDebug("upload firmware... %d bytes left", (int)bcount);
        
        if (bcount > GT_MEMORY_WINDOW_SIZE) {
            length = GT_MEMORY_WINDOW_SIZE;
            bcount -= GT_MEMORY_WINDOW_SIZE;
        } else {
            length = bcount;
            bcount = 0;
        }
        
        // write the data to the Direct Memory Window
        for(temp = 0; temp < length; temp += 4) {
            setRegister(GT_DIRECT_MEM_WIN + temp, *(((UInt32*)buf) + temp/4), false, false);
            //IODelay(GT_WRITEDELAY);
        }

        getRegister(GT_INT_EN_REG);
			
        // increment the write address
        firmReg += GT_MEMORY_WINDOW_SIZE;
        buf += length;
    } while (bcount != 0);
    
    /* now reset the device
     * clear the Reset & ClkRun bit, set the RAMBoot bit */
    statReg = getRegister(GT_CTRL_STAT_REG) & ~GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    
    statReg |= GT_CTRL_STAT_RAMBOOT;
    statReg &= ~GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    
    /* set the reset bit latches the host override and RAMBoot bits
     * into the device for operation when the reset bit is reset */
    statReg |= GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    
    /* clear the reset bit should start the whole circus */
    statReg &= ~GT_CTRL_STAT_RESET;
    setRegister(GT_CTRL_STAT_REG, statReg, true, false);
    IODelay(GT_WRITEDELAY);
    IOSleep(50);
    
    WLExit();
    
    return true;
}

bool GTDriver::_initHW() {
    _initialized = false;
    
    setRegister(GT_CTRL_BLOCK, _controlBlock.dmaAddress, true, false);
    IODelay(GT_WRITEDELAY);
    
    setRegister(GT_DEV_INT_REG, GT_DEV_INT_RESET, true, false);
    IODelay(GT_WRITEDELAY);
    
    setRegister(GT_INT_EN_REG, GT_INT_IDENT_INIT | GT_INT_IDENT_UPDATE | GT_INT_IDENT_SLEEP | GT_INT_IDENT_WAKEUP);
    IODelay(GT_WRITEDELAY);

    return true;
}

IOReturn GTDriver::_transmitInQueue(struct mbuf * m, int queue) {
    UInt32 queueSize, driverPos, i, freeFrags, offset, count;
    volatile gt_fragment *f;
    mutex_t *l;
    struct mbuf **q;
    mbuf *nm = NULL;
    struct IOPhysicalSegment vector[MAX_FRAGMENT_COUNT];
    
    if (_cardGone || _controlBlock.cb == NULL) return kIOReturnOutputDropped;
             
    switch(queue) {
        case QUEUE_TX_LOW:
            l = _dataMutex;
            queueSize = CB_TX_QSIZE;
            f = _controlBlock.cb->tx_data_low;
            q = _txDataLow;
            break;
        case QUEUE_TX_HIGH:
            l = _dataMutex;
            queueSize = CB_TX_QSIZE;
            f = _controlBlock.cb->tx_data_high;
            q = _txDataHigh;
            break;
        case QUEUE_TX_MGMT:
            l = _mgmtMutex;
            queueSize = CB_MGMT_QSIZE;
            f = _controlBlock.cb->tx_data_mgmt;
            q = _txDataMgmt;
            break;
        default:
            WLLogEmerg("Unknown Queue for transmittion. This is a bug!");
            return kIOReturnOutputDropped;
    }
    
    mutex_lock(l);
    
    freeFrags = _freeFragmentsInQueue(queue);
    i = 0;
        
    while (freeFrags == 0) {
        mutex_unlock(l);
        _stalled = true;
        return kIOReturnOutputStall;
    
        _freeTransmitQueues();
        freeFrags = _freeFragmentsInQueue(queue);
        if (freeFrags) break;
        
        IOSleep(1);
        
        if (++i > 1000) {
            WLLogDebug("Queue full queueSize %d device %d", (int)queueSize, OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[queue]));
        
            mutex_unlock(l);
            return kIOReturnOutputDropped;
        }
    }

    if (freeFrags > MAX_FRAGMENT_COUNT) freeFrags = MAX_FRAGMENT_COUNT;    //at most 4 fragments in queue
    offset = (4 - ((int)(m->m_data) & 3)) % 4;    //packet needs to be 4 byte aligned
    driverPos = OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[queue]);
    
    if (offset) { 
        //if the packet is unaligned, make a copy so it is aligned :-O~
        //if (freeFrags == 1) {
            nm = copyPacket(m, 0);
            _allocated++;
            if (!_fillFragment(&f[driverPos % queueSize], nm)) goto fillError;
            freePacket(m);
            _freed++;
            m = nm;
            goto copyDone;
        /*} else { //broken
            //make up more fragments to avoid copying of large buffers
            nm = copyPacket(m, offset);
            WLLogDebug("freeFrags: %d offset: %d nm: 0x%x packet len %d data 0x%x driverPos %d ringPos: %d", freeFrags, offset, nm, nm->m_len, *mtod(nm, int*), driverPos, _txDataLowPos);
            if (!_fillFragment(&f[driverPos % queueSize], nm, FRAGMENT_FLAG_MF)) goto fillError;
            WLLogDebug("fsize: 0x%x flags: 0x%x address:0x%x", f[driverPos % queueSize].size,  f[driverPos % queueSize].flags, OSSwapLittleToHostInt32(f[driverPos % queueSize].address));
            m_adj(m, offset);
            q[driverPos % queueSize] = nm;
            driverPos++;
            freeFrags--;
        }*/
    }

    count = _mbufCursor->getPhysicalSegmentsWithCoalesce(m, vector, 1);
    if (count == 0) {
        WLLogEmerg("Could not allocated a nice mbuf!");
        goto genericError;
    }
    
    count--;
    /*for (i = 0; i < count; i--) {
        WLLogDebug("assemble fragment number %d. address 0x%x", count, vector[count].location);
        f[driverPos % queueSize].address = vector[count].location;	// cursor is little-endian
        f[driverPos % queueSize].size = *((UInt16*)(&vector[count].length));
        f[driverPos % queueSize].flags = OSSwapHostToLittleConstInt16(FRAGMENT_FLAG_MF);
        driverPos++;
    }*/
    
    if (OSSwapLittleToHostInt32(vector[count].location) & 3) WLLogDebug("Warning: trying to transmit unaligned packet!");
    f[driverPos % queueSize].address = vector[count].location;	// cursor is little-endian
    f[driverPos % queueSize].size = *((UInt16*)(&vector[count].length));
    f[driverPos % queueSize].flags = 0;

copyDone:
    q[driverPos % queueSize] = m;
    _controlBlock.cb->driver_curr_frag[queue] = OSSwapHostToLittleInt32(++driverPos);
    
    mutex_unlock(l);

    _allocated++;
    
    if (_dozing) {
        setRegister(GT_DEV_INT_REG, GT_DEV_INT_WAKEUP);
        IODelay(GT_WRITEDELAY);
        WLLogDebug("Try to wakeup the device");
    } else {
        setRegister(GT_DEV_INT_REG, GT_DEV_INT_UPDATE);
        IODelay(GT_WRITEDELAY);
    }
 
    return kIOReturnOutputSuccess;
    
fillError:
    WLLogEmerg("Could not fill fragment for packet!");

genericError:
    mutex_unlock(l);
    if (nm) freePacket(nm);
    return kIOReturnOutputDropped;
}

#pragma mark -

bool GTDriver::_setStruc(UInt32 oid, void* data, UInt32 len, bool waitForResponse) {
    return _transmitPIM(PIMFOR_OP_SET, oid, len, data, waitForResponse);
}

bool GTDriver::_setValue(UInt32 oid, UInt32 value, bool waitForResponse) {
    value = OSSwapHostToLittleInt32(value);
    return _setStruc(oid, &value, 4, waitForResponse);
}

bool GTDriver::_getValue(UInt32 oid, UInt32 len, bool waitForResponse) {
    return _transmitPIM(PIMFOR_OP_GET, oid, len, NULL, waitForResponse);
}

void GTDriver::_fillPIMFOR(UInt32 operation, UInt32 oid, UInt32 length, pimforHeader *h) {
    h->version = PIMFOR_VERSION;
    h->operation = operation;
    h->device_id = PIMFOR_DEV_ID_MHLI_MIB;
    h->flags = 0;
    h->oid = OSSwapHostToBigInt32(oid);
    h->length = OSSwapHostToBigInt32(length);
}

bool GTDriver::_transmitPIM(UInt32 operation, UInt32 oid, UInt32 length, void* data, bool waitForResponse) {
    struct mbuf *packet;
    
    //WLEnter();
    _doAsyncIO = waitForResponse;
    
    packet = allocatePacket(length + PIMFOR_HEADER_SIZE);
    if (!packet) {
        WLLogEmerg("Could not allocate Managment frame header!");
        return false;
    }
    
    _fillPIMFOR(operation, oid, length, mtod(packet, pimforHeader*));
    if ((length>0) && (data!=NULL)) {
        memcpy(mtod(packet, UInt8*) + PIMFOR_HEADER_SIZE, data, length);
    }
    
    if (_transmitInQueue(packet, QUEUE_TX_MGMT) != kIOReturnOutputSuccess) {
        freePacket(packet);
        return false;
    }
    
    if (waitForResponse) {
        int i;
        for (i = 0; i < 10000; i++) {
            if (_doAsyncIO == false) break;
            IOSleep(1);
        }
        if (i == 10000) {
            WLLogInfo("Timeout for PIMFOR with OID 0x%x", (int)oid);
            return false;
        }
    }
    //WLExit();
    
    return true;
}

bool GTDriver::_parsePIMFOR(struct mbuf *m) {
    bool ret = false;
    pimforHeader *h;
    void *data;
    UInt32 operation, oid, version, linkSpeed;
    SInt32 length;
    objBSSList *bssList;
    //WLEnter();
    
    if (!m) {
        WLLogErr("Got an empty MBUF structure!");
        return false;
    }
    
    do {
        if (m->m_len < PIMFOR_HEADER_SIZE) {
            WLLogErr("Recieved short PIMFOR message");
            break;
        }
        h = mtod(m, pimforHeader*);
        
        version = h->version;
        if (version != PIMFOR_VERSION) {
            WLLogErr("Recieved incompatible PIMFOR message. Version %d. mbuf address 0x%x", (int)version, (int)m->m_data);
            break;
        }
        
        length = OSSwapBigToHostInt32(h->length);
        if (length) {
            if (m->m_len < length + PIMFOR_HEADER_SIZE) break;
            data = (void*)(h + 1);
        } else {
            data = NULL;
        }
 
        operation = h->operation;
        if (operation == PIMFOR_OP_ERROR) {
            WLLogErr("The Card reported an Operation error for OID 0x%x length: %d.", OSSwapBigToHostInt32(h->oid), (int)length);
            break;
        }
        if ((operation != PIMFOR_OP_RESPONSE) && (operation != PIMFOR_OP_TRAP)) {
            WLLogErr("Recieved PIMFOR with invalid operation! operation: 0x%x", (int)operation);
            break;
        }
        
        oid = OSSwapBigToHostInt32(h->oid);
        switch(oid) {
            case OID_MACADDRESS:
                if (length != 6) {
                    WLLogErr("MAC Address has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }
                memcpy(&_myAddress, data, 6);

                WLLogInfo("Set MAC Address...");
                
                break;
            case OID_LINKSTATE:
                if (length != 4) {
                    WLLogErr("LinkState has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }

                linkSpeed = OSSwapLittleToHostInt32(*((UInt32*)data));
                if (linkSpeed != _linkSpeed) {
                    _linkSpeed = linkSpeed;
                    setLinkStatus(kIONetworkLinkValid | (_linkSpeed ? kIONetworkLinkActive : 0), _getMediumWithType(MEDIUM_TYPE_AUTO), _linkSpeed * 5000000);
                    if (_linkSpeed == 0) _currentState = stateDisconnected;
                }
                break;
            case OID_BSSID:
                if (length != 6) {
                    WLLogErr("MAC BSSID has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }
                
                memcpy(_currentBSSID, data, 6);
                break;
            case OID_FREQUENCY:
                if (length != 4) {
                    WLLogErr("Frequency has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }
                
                _currentFrequency =  OSSwapLittleToHostInt32(*((int*)data));
                WLLogInfo("Current frequency is %d", (int)_currentFrequency);
                break;
            case OID_TXPOWER:
                if (length != 4) {
                    WLLogErr("Tx Power has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }
                
                WLLogInfo("Current TX Power: %u dBm", OSSwapLittleToHostInt32(*((int*)data)) / 4);
                break;
            case OID_DEAUTHENTICATE:
                WLLogInfo("Deauthenicated");
                _currentState = stateDeauthenticated;
                break;
            case OID_AUTHENTICATE:
                WLLogInfo("Authenticated");
                _currentState = stateAuthenicated;
                break;
            case OID_ASSOCIATE:
                WLLogInfo("Associated");
                _currentState = stateAssociated;
                break;
            case OID_DISASSOCIATE:
                WLLogInfo("Disassociated");
                _currentState = stateDisassociated;
                break;
            case OID_BSS_LIST:
                if (length < 4) {
                    WLLogErr("BSS list has wrong length! len: 0x%x m_len: 0x%x", (int)length, (int)m->m_len);
                    break;
                }
                
                bssList = (objBSSList*)data;
                if (OSSwapLittleToHostInt32(bssList->nr) > MAX_BSS_COUNT) {
                    WLLogErr("BSS list is too big! (%d)", (int)bssList->nr);
                    break;
                }
                
                _bssListCount = OSSwapLittleToHostInt32(bssList->nr);
                for (UInt32 i = 0; i < _bssListCount; i++) {
                    _bssList[i].ssidLength = bssList->bssList[i].ssid[0];
                    memcpy(_bssList[i].ssid, &bssList->bssList[i].ssid[1], _bssList[i].ssidLength > 32 ? 32 : _bssList[i].ssidLength);
                    memcpy(_bssList[i].address, bssList->bssList[i].address, 6);
                    _bssList[i].cap = bssList->bssList[i].capinfo;
                    if (memcmp(_currentBSSID, _bssList[i].address, 6) == 0) _bssList[i].active = 1;
                    else _bssList[i].active = 0;
                }
                WLLogInfo("Found %d Networks!", (int)_bssListCount);
                break;
            default:
                WLLogInfo("Unhandled PIMFOR OID! OID: 0x%x", (int)oid);
                break;
        }
    
        ret = true;
    } while(false);
    
    _doAsyncIO = false;
    freePacket(m);
    _rxFreed++;
    
    //WLExit()
    
    return ret;
}

#pragma mark -

int GTDriver::_inQueue(int queue) {
    if (!_controlBlock.cb) return 0;
    
    const SInt32 delta = (OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[queue]) -
                            OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[queue]));

    /* determine the amount of fragments in the queue depending on the type
     * of the queue, either transmit or receive */
    if (delta < 0) goto realityError;
    
    switch (queue) {
            /* send queues */
    case QUEUE_TX_MGMT:
            if (delta > CB_MGMT_QSIZE) goto realityError;
            return delta;
    case QUEUE_TX_LOW:
    case QUEUE_TX_HIGH:
            if (delta > CB_TX_QSIZE) goto realityError;
            return delta;
            
            /* receive queues */
    case QUEUE_RX_MGMT:
            if (delta > CB_MGMT_QSIZE) goto realityError;
            return CB_MGMT_QSIZE - delta;
    case QUEUE_RX_LOW:
    case QUEUE_RX_HIGH:
            if (delta > CB_RX_QSIZE) goto realityError;
            return CB_RX_QSIZE - delta;
    }

realityError:
    WLLogEmerg("In Queue reality error. This is a bug!");
    return 0;
}

UInt32 GTDriver::_freeFragmentsInQueue(int queue) {
    UInt32 queueSize, driverPos, devicePos;
    switch(queue) {
        case QUEUE_TX_LOW:
            queueSize = CB_TX_QSIZE;
            devicePos = _txDataLowPos;
            break;
        case QUEUE_TX_HIGH:
            queueSize = CB_TX_QSIZE;
            devicePos = _txDataHighPos;
            break;
        case QUEUE_TX_MGMT:
            queueSize = CB_MGMT_QSIZE;
            devicePos = _txDataMgmtPos;
            break;
        default:
            WLLogEmerg("Unknown Queue for transmittion. This is a bug!");
            return 0;
    }
    
    driverPos = OSSwapLittleToHostInt32(_controlBlock.cb->driver_curr_frag[queue]);
    
    if ((int)(devicePos + queueSize - driverPos) < 0) {
        WLLogEmerg("WARNING txRing %d ran over", queue);
        return 0;
    }
    return  (devicePos + queueSize - driverPos);
}

bool GTDriver::_fillFragment(volatile gt_fragment *f, struct mbuf *packet, UInt16 flags) {
    struct IOPhysicalSegment vector;
    UInt32 count;

    count = _mbufCursor->getPhysicalSegmentsWithCoalesce(packet, &vector, 1);
    if (count == 0) {
        WLLogEmerg("Could not allocated a nice mbuf!");
        return false;
    }
    
    if (OSSwapLittleToHostInt32(vector.location) & 3) {
        WLLogEmerg("Warning trying to transmit unaligned packet!");
    }
    
    f->address = vector.location;	// cursor is little-endian
    f->size = *((UInt16*)(&vector.length));
    f->flags = OSSwapHostToLittleInt16(flags);
    
    return true;
}

bool GTDriver::_allocPacketForFragment(struct mbuf **packet, volatile gt_fragment *f) {
    (*packet) = allocatePacket(MAX_FRAGMENT_SIZE);
    if (!(*packet)) {
        WLLogEmerg("Could not alloc Packet for Queue!");
        return false;
    }
    
    return _fillFragment(f, (*packet));
}

#pragma mark -

bool GTDriver::_allocQueues() {
    int i;
    
    WLEnter();
    
    _freeQueues();
    
    if (!allocatePageBlock(&_controlBlock.page)) return false;
    _controlBlock.cb = (gt_control_block*) allocateMemoryFrom(&_controlBlock.page, sizeof(gt_control_block), CACHE_ALIGNMENT, &_controlBlock.dmaAddress);
    if (!_controlBlock.cb) return false;
    
    _txDataLowPos = _txDataHighPos = _txDataMgmtPos = 0;
    
    for(i = 0; i < CB_RX_QSIZE; i++) {
        _allocPacketForFragment(&_rxDataLow[i], &_controlBlock.cb->rx_data_low[i]);
    }
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_LOW] = OSSwapHostToLittleInt32(CB_RX_QSIZE);
    _lastIndex = 0;
    
    for(i = 0; i < CB_RX_QSIZE; i++) {
        _allocPacketForFragment(&_rxDataHigh[i], &_controlBlock.cb->rx_data_high[i]);
    }
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_HIGH] = OSSwapHostToLittleInt32(CB_RX_QSIZE);
    
    for(i = 0; i < CB_MGMT_QSIZE; i++) {
        _allocPacketForFragment(&_rxDataMgmt[i], &_controlBlock.cb->rx_data_mgmt[i]);
    }
    _controlBlock.cb->driver_curr_frag[QUEUE_RX_MGMT] = OSSwapHostToLittleInt32(CB_MGMT_QSIZE);
  
    WLExit();
    
    return true;
}

bool GTDriver::_freePacketForFragment(struct mbuf **packet, volatile gt_fragment *f) {
    //WLEnter();
    
    f->flags = 0;
    f->size = 0;
    f->address = 0;
    
    if ((*packet) != NULL) {
        _freed++;
        freePacket(*packet);
        (*packet) = NULL;
    } else {
        WLLogErr("Could not free mbuf. Packet was NULL");
    }
    
    //WLReturn(true);
    return true;
}

//releases all processed packets for each transmit queue
bool GTDriver::_freeTransmitQueues() {
    bool cleaned = false;
    
    //WLEnter();
    
    for (; (int)(_txDataLowPos - OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[QUEUE_TX_LOW])) < 0; _txDataLowPos++) {
        _freePacketForFragment(&_txDataLow[_txDataLowPos % CB_TX_QSIZE], &_controlBlock.cb->tx_data_low[_txDataLowPos % CB_TX_QSIZE]);
        cleaned = true;
    }
    for (; (int)(_txDataHighPos - OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[QUEUE_TX_HIGH])) < 0; _txDataHighPos++) {
        _freePacketForFragment(&_txDataHigh[_txDataHighPos % CB_TX_QSIZE], &_controlBlock.cb->tx_data_high[_txDataHighPos % CB_TX_QSIZE]);
        cleaned = true;
    }
    for (; (int)(_txDataMgmtPos - OSSwapLittleToHostInt32(_controlBlock.cb->device_curr_frag[QUEUE_TX_MGMT])) < 0; _txDataMgmtPos++) {
        _freePacketForFragment(&_txDataMgmt[_txDataMgmtPos % CB_MGMT_QSIZE], &_controlBlock.cb->tx_data_mgmt[_txDataMgmtPos % CB_MGMT_QSIZE]);
    }
    
    if (cleaned && _stalled) {
        _stalled = false;
        _transmitQueue->start();
    }
    //WLReturn(true);
    return true;
}

bool GTDriver::_freeQueues() {
    int i;
    WLEnter();
   
    
    if (_controlBlock.cb) {
        if (!_cardGone) {
            setRegister(GT_INT_EN_REG, 0);
            setRegister(GT_CTRL_BLOCK, 0);
        }
        
        for(i = 0; i < CB_RX_QSIZE; i++) {
            _freePacketForFragment(&_rxDataLow[i], &_controlBlock.cb->rx_data_low[i]);
        }
        for(i = 0; i < CB_RX_QSIZE; i++) {
            _freePacketForFragment(&_rxDataHigh[i], &_controlBlock.cb->rx_data_high[i]);
        }
        for(i = 0; i < CB_MGMT_QSIZE; i++) {
            _freePacketForFragment(&_rxDataMgmt[i], &_controlBlock.cb->rx_data_mgmt[i]);
        }
        _freeTransmitQueues();
        
        //freePageBlock(&_controlBlock.page);
        _controlBlock.dmaAddress = 0;
        _controlBlock.cb = NULL;
    }
 
    WLExit();
    
    return true;
}