/*
        
        File:			Network.cpp
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
#include "Network.h"
#include "IEEE80211.h"
#include <cassert>
#include <arpa/inet.h>
#include <iostream>

typedef struct {
    /* 802.11 Header Info (Little Endian) 32 byte */
    unsigned short frameControl;
    unsigned char  duration;
    unsigned char  idnum;
    unsigned char  address1[6];
    unsigned char  address2[6];
    unsigned char  address3[6];
    unsigned short sequenceControl;
} __attribute__((packed)) frame;

#define	IEEE80211_ELEMID_VENDOR			0xDD

#define VENDOR_WPA_HEADER				0x0050f201
#define VENDOR_CISCO_HEADER				0x0050f205

void Network::parseTaggedData(const unsigned char* data, int length) {
	unsigned long *vendorID;
	int len;
    char ssid[33];
	
	while (length > 2) {
        switch (*data) {
		case IEEE80211_ELEMID_SSID:
            len = (*(data+1));
			if (len == 0) {
				//_ssidList["(hidden ssid)"] = new BeaconAttr();
            } else if ((length >= len+2) && (len <= 32)) {
				memcpy(ssid, data+2, len);
				ssid[len] = 0;
				_ssidList[ssid] = new BeaconAttr();
			}
            break;
		case IEEE80211_ELEMID_VENDOR:
			len=(*(data+1));
            if (len <= 4 || length < len+2) break;

			vendorID = (unsigned long*)(data + 2);
			if (*vendorID == htonl(VENDOR_CISCO_HEADER)) {
				if ((len -= 6) < 0) break;
				
				unsigned char count = (*(data+7));
				const unsigned char *ssidl = (data+8);
				unsigned char slen;
				const unsigned char *attr;
				
				while (count) {
					slen = (*(ssidl + 5));
					attr = ssidl;
					
					ssidl += 6;
					
					if ((len -= slen) < 0) break;
					
					memcpy(ssid, ssidl, slen);
					ssid[slen] = 0;
					_ssidList[ssid] = new BeaconAttr(attr);
					
					ssidl += slen;
					count--;
				}
			}
		}
		
		data++;
        length -= (*data)+2;
        data += (*data)+1;
	}
}

Network::Network(const unsigned char* data, const unsigned int length) {
	const frame *f;
	char bssid[18];
	
	assert(data != NULL);
	
	if (length < sizeof(frame)) throw NoNetwork_error("Frame too short");
	f = (const frame*) data;
	
	if ((htons(f->frameControl) & IEEE80211_VERSION_MASK) != IEEE80211_VERSION_0) throw NoNetwork_error("Illegal 802.11 version");
	if ((htons(f->frameControl) & IEEE80211_TYPE_MASK) != IEEE80211_TYPE_MGT) throw NoNetwork_error("Not a Managment Frame");
	if ((htons(f->frameControl) & IEEE80211_SUBTYPE_MASK) != IEEE80211_SUBTYPE_BEACON) throw NoNetwork_error("Not a Beacon");
	
	snprintf((char*)&bssid, 18, "%.2x:%.2x:%.2x:%.2x:%.2x:%.2x",
                     f->address3[0], f->address3[1], f->address3[2],
                     f->address3[3], f->address3[4], f->address3[5]);
					 
	_bssid = bssid;

	this->parseTaggedData(data + sizeof(frame) + 12, length - sizeof(frame) - 12);	
}

std::list<std::string> Network::description() {
	int i;
	std::list<std::string> l;
	SSIDList::const_iterator it;
	char descr[80];
	
	it = _ssidList.begin();
	for (i = 0; i < _ssidList.size(); i++) {
		if (i == 0) snprintf(descr, 80, "%-18s  %-32s  %-30s", _bssid.c_str(), ((*it).first).c_str(), (((*it).second)->description()).c_str());
		else		snprintf(descr, 80, "%-18s  %-32s  %-30s", "", ((*it).first).c_str(), (((*it).second)->description()).c_str() );
		l.push_back(descr);
		it++;
	}
	
	return l;
}
	  
const SSIDList* Network::ssidList() {
	return &_ssidList;
}

std::string Network::bssid() {
	return _bssid;
}


bool Network::test() {
	Network *n;
	const bool verbose = false;
	const SSIDList *s;
	unsigned char frame[] = "\x80\x00\x00\x00\xff\xff\xff\xff\xff\xff\x00\x12\xda\x9e\x85\xd0\x00\x12\xda\x9e\x85\xd0\xa0\x77\x8f\x91\xc9\x00\x00\x00\x00\x00\x64\x00\x21\x04\x00\x07\x61\x68\x7a\x66\x6e\x65\x74\x01\x08\x82\x84\x8b\x0c\x12\x96\x18\x24\x03\x01\x0d\x05\x04\x01\x02\x00\x00\x2a\x01\x02\x32\x04\x30\x48\x60\x6c\x85\x1e\x00\x00\x84\x00\x0f\x00\xff\x03\x01\x00\x61\x70\x33\x2d\x6b\x68\x62\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x25\xdd\x18\x00\x50\xf2\x02\x01\x01\x08\x00\x03\xa4\x00\x00\x27\xa4\x00\x00\x42\x43\x5e\x00\x62\x32\x2f\x00\xdd\x16\x00\x40\x96\x04\x00\x08\x07\xa4\x00\x00\x23\xa4\x00\x00\x42\x43\x00\x00\x62\x32\x00\x00\xdd\x05\x00\x40\x96\x03\x02\xdd\x29\x00\x50\xf2\x05\x02\x02\x00\x00\x00\x00\x10\x0d\x62\x69\x6e\x61\x65\x72\x76\x61\x72\x69\x61\x6e\x7a\x00\x00\x00\x00\x10\x0a\x74\x75\x69\x6c\x61\x6e\x64\x6f\x77\x6e";

	try {
		n = new Network(frame, sizeof(frame));
		if (!n) return false;
		
		if (verbose) std::cerr << "BSSID: " << n->bssid() << "\n";
		if (strcmp(n->bssid().c_str(), "00:12:da:9e:85:d0")) return false;
		
		s = n->ssidList();
		if (verbose) {
			std::list<std::string> x = n->description();
			std::cerr << "SSID List size: " << s->size() << "\n";
			
			std::list<std::string>::iterator it = x.begin();
			for (int i = 0; i < x.size(); i++) {
				std::cerr << "SSID List:  " << (*it) << "\n";
				it++;
			}
		}
		
		if (s->size() != 3) return false;
		
		delete n;
		
		//if (verbose) exit(0);
	} catch (NoNetwork_error e) {
		std::cerr << e.details << "\n";
		return false;
	}
	
	return true;
}
