/*
        
        File:			IEEE80211.h
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

#define	IEEE80211_VERSION_MASK				0x0300
#define	IEEE80211_VERSION_0					0x0000

#define	IEEE80211_TYPE_MASK					0x0c00
#define	IEEE80211_TYPE_MGT					0x0000
#define	IEEE80211_TYPE_CTL					0x0400
#define	IEEE80211_TYPE_DATA					0x0800

#define	IEEE80211_SUBTYPE_MASK				0xf000
#define	IEEE80211_SUBTYPE_BEACON			0x8000

#define	IEEE80211_CAPINFO_ESS				0x0100
#define	IEEE80211_CAPINFO_IBSS				0x0200
#define	IEEE80211_CAPINFO_CF_POLLABLE		0x0400
#define	IEEE80211_CAPINFO_CF_POLLREQ		0x0800
#define	IEEE80211_CAPINFO_PRIVACY			0x1000

#define	IEEE80211_CAPINFO_ESS_LE                    0x0001
#define	IEEE80211_CAPINFO_IBSS_LE                   0x0002
#define	IEEE80211_CAPINFO_CF_POLLABLE_LE            0x0004
#define	IEEE80211_CAPINFO_CF_POLLREQ_LE             0x0008
#define	IEEE80211_CAPINFO_PRIVACY_LE                0x0010

#define	IEEE80211_ELEMID_SSID			0
#define	IEEE80211_ELEMID_RATES			1
#define	IEEE80211_ELEMID_FHPARMS		2
#define	IEEE80211_ELEMID_DSPARMS		3
#define	IEEE80211_ELEMID_CFPARMS		4
#define	IEEE80211_ELEMID_TIM			5
#define	IEEE80211_ELEMID_IBSSPARMS		6
#define	IEEE80211_ELEMID_CHALLENGE		16
