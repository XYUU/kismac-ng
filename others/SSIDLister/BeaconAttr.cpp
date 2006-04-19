/*
        
        File:			BeaconAttr.cpp
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

#include "BeaconAttr.h"

BeaconAttr::BeaconAttr(const unsigned char *attr) : _primary(false) {
	memcpy(_attr, attr, 5);
};

std::string BeaconAttr::description() {
	std::string status = "";
	
	if (_primary) return "<primary network>";
	
	if (_attr[0] & 0x01) status += "EAP ";
	if (_attr[0] & 0x02) status += "WPS ";
	
	if (_attr[1] & 0x40) status += "CCKM-AES ";
	if (_attr[1] & 0x20) status += "CCKM-WEP ";
	if (_attr[1] & 0x10) status += "WPA2-PSK ";
	if (_attr[1] & 0x08) status += "WPA2-Ent ";
	if (_attr[1] & 0x04) status += "WPA1-PSK ";
	if (_attr[1] & 0x02) status += "WPA1-Ent ";

	if (_attr[4] & 0x80) status += "TKIP ";
	if (_attr[4] & 0x40) status += "WEP-104 ";
	if (_attr[4] & 0x20) status += "WEP-40 ";
	if (_attr[4] & 0x10) status += "NoEncryption ";

	if (_attr[3] & 0x08) status += "CMIC noPPK ";
	else if (_attr[3] & 0x04) status += "noCMIC PPK ";
	else if (_attr[3] & 0x02) status += "CMIC PPK ";
	else {
		if (_attr[4] & 0x01) status += "RC4-40 ";
		if (_attr[4] & 0x02) status += "RC4-104 ";
		if (_attr[4] & 0x04) status += "AES ";
	}
	
	return status;
}
