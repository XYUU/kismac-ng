/*
        
        File:			PacketSourceUSB.cpp
        Program:		SSIDLister
		Author:			Michael Rossberg
						mick@binaervarianz.de
		Description:	SSIDLister is a wireless stumbler for MacOS X & Linux.
                
        This file is part of SSIDLister.

    SSIDLister is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    SSIDLister is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SSIDLister; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "PacketSourceUSB.h"
#include <string.h>
#include <unistd.h>
#include <iostream>

#ifndef NOMACOS

typedef struct {
    /* 802.11 Header Info (Little Endian) 32 byte */
    unsigned short frameControl;
    unsigned char  duration;
    unsigned char  idnum;
    unsigned char  address1[6];
    unsigned char  address2[6];
    unsigned char  address3[6];
    unsigned short sequenceControl;
} __attribute__((packed)) Frame;


void* hopChannelThread(void* source) {
	PacketSourceUSB *s = (PacketSourceUSB*)source;
	
	while (!s->isDestructing()) {
		s->hopChannel();
		usleep(400);
	}
	
	return NULL;
}


bool PacketSourceUSB::isDestructing() {
	return _destructing;
}

void PacketSourceUSB::hopChannel() {
	if (_channel == 13 && (((_allowedChannels >> 13) & 0x0001) == 0)) {
		_channel = 2;
	} else {
		for (_channel+=2; _channel <= 14; _channel++) 
			if (((_allowedChannels >> (_channel - 1)) & 0x0001) != 0) break;
	}
	
	if (_channel == 15) 
		for (_channel = 1; _channel <= 14; _channel++) 
			if (((_allowedChannels >> (_channel - 1)) & 0x0001) != 0) break;

    _driver->setChannel(_channel);
	
}

PacketSourceUSB::PacketSourceUSB() {	
	_destructing = false;
	_driver = new USBIntersilJack;
	_driver->startMatching();
	if (!_driver->devicePresent()) throw PacketSource_error("No device found.");
    if (!_driver->getAllowedChannels(&_allowedChannels)) throw PacketSource_error("No allowed channel found.");

	for (_channel = 1; _channel <= 14; _channel++) 
		if (((_allowedChannels >> (_channel - 1)) & 0x0001) != 0) break;
    
	if (_channel == 15) throw PacketSource_error("No valid channel found.");
	
	if (!_driver->startCapture(_channel)) throw PacketSource_error("Could not start Capture.");
	pthread_create(&_hopper, NULL, hopChannelThread, this);
}

const unsigned char* PacketSourceUSB::getData(int* size) {
	WLFrame *f;
	Frame *f2;
    int p = 0;
	
    while (((f = _driver->recieveFrame()) == NULL) || (f->dataLen > 3000)) {
		if (_destructing) return NULL;
		p++;
		if (p > 50) throw PacketSource_error("Device is broken.");
	}
	
	
	f2 = (Frame*) _frame;
	f2->frameControl = f->frameControl;
	memcpy(f2->address1, f->address1, 18);
	memcpy(f2+1, f+1, f->dataLen);
	
	*size = f->dataLen + sizeof(Frame);
	
    return _frame;
}

PacketSourceUSB::~PacketSourceUSB() {
	_destructing = true;
	pthread_cancel(_hopper);
	sleep(5);
	
	delete _driver;
}
	
#endif 
