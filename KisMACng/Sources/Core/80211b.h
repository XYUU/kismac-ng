/*
        
        File:			80211b.h
        Program:		KisMAC
		Author:			Michael Rossberg
						mick@binaervarianz.de
		Description:	KisMAC is a wireless stumbler for MacOS X.
                
        This file is part of KisMAC.

    KisMAC is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    KisMAC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with KisMAC; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

typedef struct _WLFrame {
    /* Control Fields (Little Endian) 14 byte*/ 
    UInt16 status;
    UInt16 channel;
    UInt16 reserved1;
    UInt8  signal;
    UInt8  silence;
    UInt8  rate;
    UInt8  rx_flow;
    UInt8  tx_rtry;
    UInt8  tx_rate;
    UInt16 txControl;

    /* 802.11 Header Info (Little Endian) 32 byte */
    UInt16 frameControl;
    UInt8  duration;
    UInt8  idnum;
    UInt8  address1[6];
    UInt8  address2[6];
    UInt8  address3[6];
    UInt16 sequenceControl;
    UInt8  address4[6];
    UInt16 dataLen;

    /* 802.3 Header Info (Big Endian) 14 byte*/
    UInt8  dstAddr[6];
    UInt8  srcAddr[6];
    UInt16 length;
} __attribute__((packed)) WLFrame;

typedef struct {
    /* Control Fields (Little Endian) 14 byte*/ 
    UInt16 status;
    UInt16 channel;
    UInt16 reserved1;
    UInt8  signal;
    UInt8  silence;
    UInt8  rate;
    UInt8  rx_flow;
    UInt8  tx_rtry;
    UInt8  tx_rate;
    UInt16 txControl;
} __attribute__((packed)) WLPrismHeader;

typedef struct _WLCryptedFrame {
    WLFrame frame;
    UInt8   IV[3];
    UInt8   keyID;
} __attribute__((packed)) WLCryptedFrame;

typedef struct _special_set {
    UInt16	resv;
    UInt16	wi_channel;
    UInt16	wi_port;
    UInt16	wi_beaconint;
    UInt16	wi_ssidlen;
    char	wi_ssid[256];
    char	wi_mac[6];
} special_set;    

typedef struct _frame8021x {
    UInt8       version;
    UInt8       type;
    UInt16      length;
    UInt8       data;
} __attribute__((packed)) frame8021x;

typedef struct _frameLEAP {
    UInt8       code;
    UInt8       ID;
    UInt16      length;
    UInt8       type;
    UInt8       version;
    UInt8       reserved;
    UInt8       count;
    UInt8       challenge[8];
    UInt8       name;
} __attribute__((packed)) frameLEAP;

#define HDR_SIZE        16
#define LLC_SIZE		8
#define WEP_SIZE		4
#define ARPDATA_SIZE	28
#define WEP_CRC_SIZE	4
#define ETHERPADDING	18

#define TCPACK_MIN_SIZE		(40 + HDR_SIZE)
#define TCPACK_MAX_SIZE		(52 + HDR_SIZE)
#define TCPRST_SIZE			(40 + HDR_SIZE)
#define ARP_SIZE			(WEP_SIZE + LLC_SIZE + ARPDATA_SIZE + WEP_CRC_SIZE)
#define ARP_SIZE_PADDING 	(ARP_SIZE + ETHERPADDING)

//this is all for a big endian system...

#define	IEEE80211_VERSION_MASK	0x0300
#define	IEEE80211_VERSION_0		0x0000

#define	IEEE80211_TYPE_MASK		0x0c00
#define	IEEE80211_TYPE_MGT		0x0000
#define	IEEE80211_TYPE_CTL		0x0400
#define	IEEE80211_TYPE_DATA		0x0800

#define	IEEE80211_SUBTYPE_MASK		0xf000
#define	IEEE80211_SUBTYPE_ASSOC_REQ	0x0000
#define	IEEE80211_SUBTYPE_ASSOC_RESP	0x1000
#define	IEEE80211_SUBTYPE_REASSOC_REQ	0x2000
#define	IEEE80211_SUBTYPE_REASSOC_RESP	0x3000
#define	IEEE80211_SUBTYPE_PROBE_REQ	0x4000
#define	IEEE80211_SUBTYPE_PROBE_RESP	0x5000
#define	IEEE80211_SUBTYPE_BEACON	0x8000
#define	IEEE80211_SUBTYPE_ATIM		0x9000
#define	IEEE80211_SUBTYPE_DISASSOC	0xa000
#define	IEEE80211_SUBTYPE_AUTH		0xb000
#define	IEEE80211_SUBTYPE_DEAUTH	0xc000

#define	IEEE80211_SUBTYPE_PS_POLL	0xa000
#define	IEEE80211_SUBTYPE_RTS		0xb000
#define	IEEE80211_SUBTYPE_CTS		0xc000
#define	IEEE80211_SUBTYPE_ACK		0xd000
#define	IEEE80211_SUBTYPE_CF_END	0xe000
#define	IEEE80211_SUBTYPE_CF_END_ACK	0xf000

#define	IEEE80211_SUBTYPE_CF_ACK	0x1000
#define	IEEE80211_SUBTYPE_CF_POLL	0x2000
#define	IEEE80211_SUBTYPE_NODATA	0x4000

#define	IEEE80211_DIR_MASK		0x0003
#define	IEEE80211_DIR_NODS		0x0000	/* STA->STA */
#define	IEEE80211_DIR_TODS		0x0001	/* STA->AP  */
#define	IEEE80211_DIR_FROMDS		0x0002	/* AP ->STA */
#define	IEEE80211_DIR_DSTODS		0x0003	/* AP ->AP  */

#define	IEEE80211_MORE_FRAG		0x0004
#define	IEEE80211_RETRY			0x0008
#define	IEEE80211_PWR_MGT		0x0010
#define	IEEE80211_MORE_DATA		0x0020
#define	IEEE80211_WEP			0x0040
#define	IEEE80211_ORDER			0x0080

#define	IEEE80211_CAPINFO_ESS			0x0100
#define	IEEE80211_CAPINFO_IBSS			0x0200
#define	IEEE80211_CAPINFO_CF_POLLABLE		0x0400
#define	IEEE80211_CAPINFO_CF_POLLREQ		0x0800
#define	IEEE80211_CAPINFO_PRIVACY		0x1000

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

#define	IEEE80211_ELEMID_VENDOR			0xDD

#define VENDOR_WPA_HEADER				0x0050f201
#define VENDOR_CISCO_HEADER				0x0050f205

#define WPA_FLAG_REQUEST                0x0800
#define WPA_FLAG_ERROR                  0x0400
#define WPA_FLAG_SECURE                 0x0200
#define WPA_FLAG_MIC                    0x0100
#define WPA_FLAG_ACK                    0x0080
#define WPA_FLAG_INSTALL                0x0040
#define WPA_FLAG_KEYID                  0x0030
#define WPA_FLAG_KEYTYPE                0x0008
#define WPA_FLAG_KEYCIPHER              0x0007

#define WPA_FLAG_KEYTYPE_PAIRWISE       0x0008
#define WPA_FLAG_KEYTYPE_GROUPWISE      0x0000

#define WPA_FLAG_KEYCIPHER_HMAC_MD5     0x0001
#define WPA_FLAG_KEYCIPHER_AES_CBC      0x0002

#define WPA_NONCE_LENGTH                32
#define WPA_EAPOL_LENGTH                99
#define WPA_EAP_MIC_LENGTH              16

#define WPA_PMK_LENGTH                  32
