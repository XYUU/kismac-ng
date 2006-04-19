/*
        
        File:			PacketSourcePCAP.h
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

#include "PacketSource.h"
#include <pcap.h>

class PacketSourcePCAP : public PacketSource {
private:
	pcap_t *_source;
	int		_headerOffset;
	
public:
	PacketSourcePCAP(bool live, const char* filename);
	virtual ~PacketSourcePCAP();
	
	const unsigned char* getData(int* size);
};
