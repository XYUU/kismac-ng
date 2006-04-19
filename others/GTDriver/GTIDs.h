/*
        
        File:			GTIDs.h
        Program:		GTDriver
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		GTDriver is a free driver for PrismGT based cards under OS X.
                
        This file is part of GTDriver. Parts of this file are stolen from the Prism54 project.

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

/* PIMFOR package definitions */
#define PIMFOR_ETHERTYPE                        0x8828
#define PIMFOR_HEADER_SIZE                      12
#define PIMFOR_VERSION                          1
#define PIMFOR_OP_GET                           0
#define PIMFOR_OP_SET                           1
#define PIMFOR_OP_RESPONSE                      2
#define PIMFOR_OP_ERROR                         3
#define PIMFOR_OP_TRAP                          4
#define PIMFOR_OP_RESERVED                      5	/* till 255 */
#define PIMFOR_DEV_ID_MHLI_MIB                  0
#define PIMFOR_FLAG_APPLIC_ORIGIN               0x01
#define PIMFOR_FLAG_LITTLE_ENDIAN               0x02

#define OID_MACADDRESS      0x00000000
#define OID_LINKSTATE       0x00000001
#define OID_BSSTYPE         0x10000000
#define OID_BSSID           0x10000001
#define OID_SSID            0x10000002
#define OID_AUTHENABLE      0x12000000
#define OID_PRIVACYINVOKED  0x12000001
#define OID_DEFKEYID        0x12000003
#define OID_DEFKEY1         0x12000004
#define OID_DEFKEY2         0x12000005
#define OID_DEFKEY3         0x12000006
#define OID_DEFKEY4         0x12000007
#define OID_CHANNEL         0x17000007
#define OID_FREQUENCY       0x17000011
#define OID_DEAUTHENTICATE  0x18000000
#define OID_AUTHENTICATE    0x18000001
#define OID_DISASSOCIATE    0x18000002
#define OID_ASSOCIATE       0x18000003
#define OID_SCAN            0x18000004
#define OID_MAXFRAMEBURST   0x1B000008
#define OID_BSS_LIST        0x1C000043
#define OID_MODE            0xFF020003
#define OID_CONFIG          0xFF020008
#define OID_TXPOWER         0xFF02000F

#define PRIV_WEP    0
#define PRIV_TKIP   1

/* PCI Memory Area */
#define GT_HARDWARE_REG                     0x0000
#define GT_CARDBUS_CIS                      0x0800
#define GT_DIRECT_MEM_WIN                   0x1000

/* Hardware registers */
#define GT_DEV_INT_REG                      0x0000
#define GT_INT_IDENT_REG                    0x0010
#define GT_INT_ACK_REG                      0x0014
#define GT_INT_EN_REG                       0x0018
#define GT_CTRL_BLOCK                       0x0020
#define GT_DIR_MEM_BASE_REG                 0x0030
#define GT_CTRL_STAT_REG                    0x0078

/* Device Interrupt register bits */
#define GT_DEV_INT_RESET                    0x0001
#define GT_DEV_INT_UPDATE                   0x0002
#define GT_DEV_INT_WAKEUP                   0x0008
#define GT_DEV_INT_SLEEP                    0x0010

/* Interrupt Identification/Acknowledge/Enable register bits */
#define GT_INT_IDENT_UPDATE                 0x0002
#define GT_INT_IDENT_INIT                   0x0004
#define GT_INT_IDENT_WAKEUP                 0x0008
#define GT_INT_IDENT_SLEEP                  0x0010
#define GT_INT_SOURCES                      0x001E

/* Control/Status register bits */
#define GT_CTRL_STAT_SLEEPMODE              0x00000200
#define	GT_CTRL_STAT_CLKRUN                 0x00800000
#define GT_CTRL_STAT_RESET                  0x10000000
#define GT_CTRL_STAT_RAMBOOT                0x20000000
#define GT_CTRL_STAT_STARTHALTED            0x40000000
#define GT_CTRL_STAT_HOST_OVERRIDE          0x80000000

#define GT_DEV_FIRMWARE_ADDRESS             0x20000
#define GT_MEMORY_WINDOW_SIZE               0x01000

// Control Block definitions
#define CB_QCOUNT                       6
#define CB_RX_QSIZE                     8
#define CB_TX_QSIZE                     32
#define CB_MGMT_QSIZE                   4

#define MGMT_FRAME_SIZE                         1500 /* >= size struct obj_bsslist */
#define MGMT_TX_FRAME_COUNT                     24	/* max 4 + spare 4 + 8 init */
#define MGMT_RX_FRAME_COUNT                     24	/* 4*4 + spare 8 */
#define MGMT_FRAME_COUNT                        (MGMT_TX_FRAME_COUNT + MGMT_RX_FRAME_COUNT)
#define MGMT_QBLOCK                             MGMT_FRAME_COUNT * MGMT_FRAME_SIZE
#define CONTROL_BLOCK_SIZE                      1024	/* should be enough */
#define PSM_FRAME_SIZE                          1536
#define PSM_MINIMAL_STATION_COUNT               64
#define MAX_TRAP_RX_QUEUE                       4
#define HOST_MEM_BLOCK                          MGMT_QBLOCK + CONTROL_BLOCK_SIZE + PSM_BUFFER_SIZE

/* Fragment package definitions */
#define FRAGMENT_FLAG_MF                        0x0001
#define MAX_FRAGMENT_COUNT                      4

/* In monitor mode frames have a header. I don't know exactly how big those
 * frame can be but I've never seen any frame bigger than 1584... :
 */
#define MAX_FRAGMENT_SIZE_RX	                1600

#define QUEUE_RX_LOW    0
#define QUEUE_TX_LOW    1
#define QUEUE_RX_HIGH   2
#define QUEUE_TX_HIGH   3
#define QUEUE_RX_MGMT   4
#define QUEUE_TX_MGMT   5

typedef struct {
    volatile UInt32 address;                        // physical address on host
    volatile UInt16 size;                           // packet size
    volatile UInt16 flags;                          // set of bit-wise flags
} gt_fragment;

typedef struct {
    volatile UInt32 driver_curr_frag[CB_QCOUNT];
    volatile UInt32 device_curr_frag[CB_QCOUNT];
    volatile gt_fragment rx_data_low[CB_RX_QSIZE];
    volatile gt_fragment tx_data_low[CB_TX_QSIZE];
    volatile gt_fragment rx_data_high[CB_RX_QSIZE];
    volatile gt_fragment tx_data_high[CB_TX_QSIZE];
    volatile gt_fragment rx_data_mgmt[CB_MGMT_QSIZE];
    volatile gt_fragment tx_data_mgmt[CB_MGMT_QSIZE];
} gt_control_block;

typedef struct {
    UInt8   version;
    UInt8   operation;
    UInt32  oid;
    UInt8   device_id;
    UInt8   flags;
    UInt32  length;
} __attribute__ ((packed)) pimforHeader;

typedef struct {
    UInt8   type;
    UInt8   len;
    UInt8   key[32];
} __attribute__ ((packed)) keyObject;

typedef struct {
	UInt8   address[6];
	UInt8   pad[2];
	UInt8   state;
	UInt8   reserved;
	UInt16  age;

	UInt8   quality;
	UInt8   rssi;

	UInt8   ssid[34];
	UInt16  channel;
	UInt8   beacon_period;
	UInt8   dtim_period;
	UInt16  capinfo;
	UInt16  rates;
	UInt16  basic_rates;
        UInt16  reserved2;
} __attribute__ ((packed)) objBSS;

typedef struct {
	UInt32 nr;
	objBSS bssList[MAX_BSS_COUNT];
} __attribute__ ((packed)) objBSSList;

typedef struct {
	UInt16 sweep;

	UInt16 type;
	UInt16 min;
	UInt16 max;
	UInt16 interval;

	UInt16 nr;
        UInt16 mhz[32];
} __attribute__ ((packed)) objScan;

enum oid_inl_mode_t {
    INL_MODE_NONE = 0xFFFFFFFF,
    INL_MODE_PROMISCUOUS = 0,
    INL_MODE_CLIENT = 1,
    INL_MODE_AP = 2,
};

enum oid_inl_config_t {
    INL_CONFIG_NOTHING = 0x00,
    INL_CONFIG_MANUALRUN = 0x01,
    INL_CONFIG_FRAMETRAP = 0x02,
    INL_CONFIG_RXANNEX = 0x04,
    INL_CONFIG_TXANNEX = 0x08,
    INL_CONFIG_WDS = 0x10
};

enum dot11_bsstype_t {
    DOT11_BSSTYPE_NONE = 0,
    DOT11_BSSTYPE_INFRA = 1,
    DOT11_BSSTYPE_IBSS = 2,
    DOT11_BSSTYPE_ANY = 3
};

enum dot11_auth_t {
    DOT11_AUTH_NONE = 0,
    DOT11_AUTH_OS = 1,
    DOT11_AUTH_SK = 2,
    DOT11_AUTH_BOTH = 3
};

enum dot11_scantype_t {
    DOT11_SCAN_PASSIVE = 0,
    DOT11_SCAN_ACTIVE = 1,
    DOT11_SCAN_SELECTIVE = 2
};

enum dot11_maxframeburst_t { 
    /* Values for DOT11_OID_MAXFRAMEBURST */
    DOT11_MAXFRAMEBURST_OFF = 0, /* Card firmware default */
    DOT11_MAXFRAMEBURST_MIXED_SAFE = 650, /* 802.11 a,b,g safe */
    DOT11_MAXFRAMEBURST_IDEAL = 1300, /* Theoretical ideal level */
    DOT11_MAXFRAMEBURST_MAX = 5000, /* Use this as max,
            * Note: firmware allows for greater values. This is a
            * recommended max. I'll update this as I find
            * out what the real MAX is. Also note that you don't necessarily
            * get better results with a greater value here.
            */
};
