/*
        
        File:			PacketSourcePCAP.cpp
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

#include "PacketSourcePCAP.h"
#include <iostream>

#ifndef DLT_IEEE802_11_RADIO
#define DLT_IEEE802_11_RADIO	127	/* 802.11 plus BSD radio header */
#endif 

PacketSourcePCAP::PacketSourcePCAP(bool live, const char* filename) {
	char err[PCAP_ERRBUF_SIZE];
	
	if (!live) {
		_source = pcap_open_offline(filename, err);
	} else {
		char *device;
		device = new char[strlen(filename) + 1];
		strcpy(device, filename);
		_source = pcap_open_live(device, 3000, 1, 0, err);
		delete [] device;
	}
	
	if (!_source) {
		std::cerr << err << "\n";
		throw PacketSource_error("Error opening PCAP file.");
	}
	
	switch(pcap_datalink(_source)) {
	case DLT_IEEE802_11:
		_headerOffset = 0;
		break;
	case DLT_PRISM_HEADER:
		_headerOffset = 144; //new wlanng header type 
		break;
	case DLT_IEEE802_11_RADIO:
	case DLT_AIRONET_HEADER:
		throw PacketSource_error("Unsupported 802.11 Datalink mode.");
		break;
	default:
		throw PacketSource_error("Unknown Datalink type.");
	}
	
}

const unsigned char* PacketSourcePCAP::getData(int* size) {
    struct pcap_pkthdr h;
	const unsigned char *data;
	
	data = pcap_next(_source, &h);
	if (!data) return NULL;
	
	*size = (h.caplen - _headerOffset);
	
	return data + _headerOffset;
}

PacketSourcePCAP::~PacketSourcePCAP() {
	if (_source) pcap_close(_source);

}
	
