/*
        
        File:			Network.h
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
#include <map>
#include <string>
#include <list>

#include "BeaconAttr.h"

struct NoNetwork_error {
	const char * details;
	NoNetwork_error(const char* d) { details = d; }
};

typedef std::map<std::string, BeaconAttr*> SSIDList;

class Network {
private:
	SSIDList _ssidList;
	std::string _bssid;
	
	void parseTaggedData(const unsigned char* data, int length);

public:
	Network(const unsigned char* data, const unsigned int length);
	
	std::list<std::string> description();

	const SSIDList*		ssidList();
	std::string	bssid();
	
	
	static bool test();
};
