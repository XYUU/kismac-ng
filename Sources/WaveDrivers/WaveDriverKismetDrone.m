/*
        
        File:			WaveDriverKismetDrone.m
        Program:		KisMAC
		Author:			Geordie Millar
						themacuser@gmail.com
						Contains a lot of code from Kismet - 
						http://kismetwireless.net/
						
		Description:	Scan with a Kismet drone (as opposed to kismet server) in KisMac.
		
		Details:		Tested with kismet_drone 2006.04.R1 on OpenWRT White Russian RC6 on a Diamond Digital R100
						(broadcom mini-PCI card, wrt54g capturesource)
						and kismet_drone 2006.04.R1 on Voyage Linux on a PC Engines WRAP.2E
						(CM9 mini-PCI card, madwifing)
                
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

#import "WaveDriverKismetDrone.h"
#import "ImportController.h"
#import "WaveHelper.h"
#import <BIGeneric/BIGeneric.h>

@implementation WaveDriverKismetDrone

+ (enum WaveDriverType) type {
    return passiveDriver;
}

+ (bool) allowsInjection {
    return NO;
}

+ (bool) wantsIPAndPort {
    return YES;
}

+ (bool) allowsChannelHopping {
    return NO;
}

+ (NSString*) description {
    return NSLocalizedString(@"Kismet Drone (raw packets), passive mode", "long driver description");
}

+ (NSString*) deviceName {
    return NSLocalizedString(@"Kismet Drone", "short driver description");
}

#pragma mark -


+ (BOOL)deviceAvailable {
	return YES;
}


+ (int) initBackend {
	return YES;
}

+ (bool) loadBackend {
	return YES;
}

+ (bool) unloadBackend {
	return YES;
}

#pragma mark -

- (id)init {
	return self;
}

#pragma mark -

- (unsigned short) getChannelUnCached {
	return _currentChannel;
}

- (bool) setChannel:(unsigned short)newChannel {
	_currentChannel = newChannel;
	return YES;
}

- (bool) startCapture:(unsigned short)newChannel {
    return YES;
}

-(bool) stopCapture {
	close(drone_fd);
    return YES;
}

#pragma mark -

-(bool) startedScanning {
	NSUserDefaults *defs;
    defs = [NSUserDefaults standardUserDefaults];
	const char* hostname;
	unsigned int port;

	int foundhostname=0;
	int foundport=0;
	
	NSArray *activeDrivers;
	activeDrivers = [defs objectForKey:@"ActiveDrivers"];
	NSEnumerator *e = [activeDrivers objectEnumerator];
	NSDictionary *drvr;
	@try { // todo: not multiple instance safe yet. not a problem currently.
		while ( (drvr = [e nextObject]) ) {
			if ([[drvr objectForKey:@"driverID"] isEqualToString:@"WaveDriverKismetDrone"]) {
				hostname = [[drvr objectForKey:@"kismetserverhost"] cString];
				foundhostname = 1;
				port = [[drvr objectForKey:@"kismetserverport"] intValue];
				foundport = 1;
			}
		}
	}
	@catch (NSException * ex) {
		NSLog(@"Exception getting the hostname and port from plist...");
		NSLog(@"Error getting host and port!"); 
			NSRunCriticalAlertPanel(
            NSLocalizedString(@"No host/port set to connect to!", "Error dialog title"),
            NSLocalizedString(@"Check that one is set in the preferences", "LONG desc"),
            OK, Nil, Nil);
		return nil;
	}

	if (foundhostname + foundport < 2) {
		NSLog(@"Error getting the hostname and port from plist...");
		NSLog(@"Error getting host and port!"); 
		NSRunCriticalAlertPanel(
           NSLocalizedString(@"No host/port set to connect to!", "Error dialog title"),
            NSLocalizedString(@"Check that one is set in the preferences", "LONG desc"),
            OK, Nil, Nil);
		return nil;
	}

	UInt32 ip = inet_addr(hostname);
		
	drone_sock.sin_addr.s_addr = ip;


	memset(&drone_sock, 0, sizeof(drone_sock));
	drone_sock.sin_addr.s_addr = ip;
	drone_sock.sin_family = AF_INET;
	drone_sock.sin_port = htons(port); // option as well
	
	if ((drone_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        NSLog(@"socket() failed %d (%s)\n", errno, strerror(errno));
			NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"%s",strerror(errno)],
            OK, Nil, Nil);
		return nil;
    }

	local_sock.sin_family = AF_INET;
    local_sock.sin_addr.s_addr = htonl(INADDR_ANY);
    local_sock.sin_port = htons(0);

    if (bind(drone_fd, (struct sockaddr *) &local_sock, sizeof(local_sock)) < 0) {
         NSLog(@"bind() failed %d (%s)\n", errno, strerror(errno));
			NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"%s",strerror(errno)],
            OK, Nil, Nil);
        return NULL;
    }

    // Connect
    if (connect(drone_fd, (struct sockaddr *) &drone_sock, sizeof(drone_sock)) < 0) {
         NSLog(@"connect() failed %d (%s)\n", errno, strerror(errno));
			NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"%s",strerror(errno)],
            OK, Nil, Nil);
		return nil;
    }

    valid = 1;

    resyncs = 0;
    resyncing = 0;
	
    stream_recv_bytes = 0;

	return YES;
}

#pragma mark -

- (WLFrame*) nextFrame {
	WLFrame *thisFrame;
	static UInt8 frame[2500];
	thisFrame = (WLFrame*)frame;
	
	uint8_t *inbound;
	int ret = 0;
	fd_set rset;
	struct timeval tm;
	unsigned int offset = 0;
		
	top:;
	int noValidFrame = 1;
	
	while (noValidFrame) {
	   if (stream_recv_bytes < sizeof(struct stream_frame_header)) {
			inbound = (uint8_t *) &fhdr;
			if ((ret = read(drone_fd, &inbound[stream_recv_bytes],
				 (ssize_t) sizeof(struct stream_frame_header) - stream_recv_bytes)) < 0) {
				NSLog(@"drone read() error getting frame header %d:%s",
						 errno, strerror(errno));
							NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Drone read() error getting frame header",
            OK, Nil, Nil);
			}
			stream_recv_bytes += ret;

			if (stream_recv_bytes < sizeof(struct stream_frame_header))
				goto top;
			
			// Validate it
			if (ntohl(fhdr.frame_sentinel) != STREAM_SENTINEL) {
				int8_t cmd = STREAM_COMMAND_FLUSH;
				int ret = 0;

				stream_recv_bytes = 0;
				resyncs++;

				if (resyncs > 20) {
				   NSLog(@"too many resync attempts, something is wrong.");
					NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Resync attempted too many times.",
            OK, Nil, Nil);
					return NULL;
				}

				if (resyncing == 1)
					goto top;

				resyncing = 1;
				
				if ((ret = write(drone_fd, &cmd, 1)) < 1) {
					NSLog(@"write() error attempting to flush "
							 "packet stream: %d %s",
							 errno, strerror(errno));
							 
							NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Write error flushing packet stream",
            OK, Nil, Nil);
				
					return NULL;
				}
			}
		}
		
		////////
		offset = sizeof(struct stream_frame_header);
		if (fhdr.frame_type == STREAM_FTYPE_VERSION && stream_recv_bytes >= offset && 
			stream_recv_bytes < offset + sizeof(struct stream_version_packet)) {

			inbound = (uint8_t *) &vpkt;
			if ((ret = read(drone_fd, &inbound[stream_recv_bytes - offset],
							(ssize_t) sizeof(struct stream_version_packet) - 
							(stream_recv_bytes - offset))) < 0) {

				NSLog(@"drone read() error getting version "
						 "packet %d:%s", errno, strerror(errno));
				
						 			NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Read error getting version",
            OK, Nil, Nil);		 
				
				return NULL;
			}
			stream_recv_bytes += ret;

			// Leave if we aren't done
			if ((stream_recv_bytes - offset) < sizeof(struct stream_version_packet))
				goto top;

			// Validate
			if (ntohs(vpkt.drone_version) != STREAM_DRONE_VERSION) {
				NSLog(@"version mismatch:  Drone sending version %d, "
						 "expected %d.", ntohs(vpkt.drone_version), STREAM_DRONE_VERSION);
							NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"version mismatch:  Drone sending version %d, expected %d.", ntohs(vpkt.drone_version), STREAM_DRONE_VERSION],
            OK, Nil, Nil);
				return NULL;
			}

			stream_recv_bytes = 0;

			 NSLog(@"debug - version packet valid\n\n");
		} 

	if (fhdr.frame_type == STREAM_FTYPE_PACKET && stream_recv_bytes >= offset &&
			stream_recv_bytes < offset + sizeof(struct stream_packet_header)) {
			
			// Bail if we have a frame header too small for a packet of any sort
			if (ntohl(fhdr.frame_len) <= sizeof(struct stream_packet_header)) {
				NSLog(@"frame too small to hold a packet.");
				NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"Frame too small to hold a packet", ntohs(vpkt.drone_version), STREAM_DRONE_VERSION],
            OK, Nil, Nil);
				return NULL;
			}

			inbound = (uint8_t *) &phdr;
			if ((ret = read(drone_fd, &inbound[stream_recv_bytes - offset],
							(ssize_t) sizeof(struct stream_packet_header) - 
							(stream_recv_bytes - offset))) < 0) {
				NSLog(@"drone read() error getting packet "
						 "header %d:%s", errno, strerror(errno));
				
				NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"drone read() error getting packet header %d:%s", errno, strerror(errno)],
            OK, Nil, Nil);
						 
				return NULL;
			}
			stream_recv_bytes += ret;

			// Leave if we aren't done
			if ((stream_recv_bytes - offset) < sizeof(struct stream_packet_header))
				goto top;

			if (ntohs(phdr.drone_version) != STREAM_DRONE_VERSION) {
				NSLog(@"version mismatch:  Drone sending version %d, "
						 "expected %d.", ntohs(phdr.drone_version), STREAM_DRONE_VERSION);
			NSRunCriticalAlertPanel(@"The connection to the Kismet drone failed",
			[NSString stringWithFormat:@"version mismatch:  Drone sending version %d, expected %d.", ntohs(phdr.drone_version), STREAM_DRONE_VERSION], 
			OK, Nil, Nil);

				
				return NULL;
			}

			if (ntohl(phdr.caplen) <= 0 || ntohl(phdr.len) <= 0) {
				NSLog(@"drone sent us a 0-length packet.");
				 NSRunCriticalAlertPanel(NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Drone sent us a zero-length packet",
            OK, Nil, Nil);
				return NULL;
			}

			if (ntohl(phdr.caplen) > MAX_PACKET_LEN || ntohl(phdr.len) > MAX_PACKET_LEN) {
				NSLog(@"drone sent us an oversized packet.");
				NSRunCriticalAlertPanel(NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			@"Drone sent us an oversized packet",
            OK, Nil, Nil);
				return NULL;
			}
			
			// See if we keep looking for more packet pieces
			FD_ZERO(&rset);
			FD_SET(drone_fd, &rset);
			tm.tv_sec = 0;
			tm.tv_usec = 0;

			if (select(drone_fd + 1, &rset, NULL, NULL, &tm) <= 0)
				goto top;

		}

		offset = sizeof(struct stream_frame_header) + sizeof(struct stream_packet_header);
		if (fhdr.frame_type == STREAM_FTYPE_PACKET && stream_recv_bytes >= offset) {

			unsigned int plen = (uint32_t) ntohl(phdr.len);

			inbound = (uint8_t *) databuf;
			if ((ret = read(drone_fd, &inbound[stream_recv_bytes - offset],
							(ssize_t) plen - (stream_recv_bytes - offset))) < 0) {
				NSLog(@"drone read() error getting packet "
						 "header %d:%s", errno, strerror(errno));
				
						 NSRunCriticalAlertPanel(
            NSLocalizedString(@"The connection to the Kismet drone failed", "Error dialog title"),
			[NSString stringWithFormat:@"drone read() error getting packet header %d:%s", errno, strerror(errno)],
            OK, Nil, Nil);		 
				
				return NULL;
			}
			stream_recv_bytes += ret;

			if ((stream_recv_bytes - offset) < plen)
				goto top;
			

		thisFrame->dataLen = (UInt16) ntohl(phdr.len);
		thisFrame->signal = (UInt8) ntohs(phdr.signal);
		thisFrame->channel = (UInt16) phdr.channel;
		thisFrame->rate = (UInt8) ntohl(phdr.datarate);
	
		memcpy(&thisFrame->address1,&databuf[4],6);
		memcpy(&thisFrame->address3,&databuf[16],6);
		memcpy(&thisFrame->address2,&databuf[10],6); 
		memcpy(&thisFrame->address4,&databuf[24],6);
	
		frame_control *fc = (frame_control *) databuf;
		thisFrame->frameControl = 0;
	
		if (fc->to_ds == 0 && fc->from_ds == 0)
			thisFrame->frameControl = thisFrame->frameControl | IEEE80211_DIR_NODS;
		else if (fc->to_ds == 0 && fc->from_ds == 1)
			thisFrame->frameControl = thisFrame->frameControl | IEEE80211_DIR_FROMDS;
		else if (fc->to_ds == 1 && fc->from_ds == 0)
			thisFrame->frameControl = thisFrame->frameControl | IEEE80211_DIR_TODS;
		else if (fc->to_ds == 1 && fc->from_ds == 1)
		   thisFrame->frameControl = thisFrame->frameControl | IEEE80211_DIR_DSTODS;
		
		if (fc->type == 0) {
			thisFrame->frameControl = thisFrame->frameControl | IEEE80211_TYPE_MGT;
		} else if (fc->type == 2) {
			thisFrame->frameControl = thisFrame->frameControl | IEEE80211_TYPE_DATA;
		} else {
			//thisFrame->frameControl = thisFrame->frameControl | IEEE80211_TYPE_DATA;
		}
		
		if (fc->subtype < 16) {
			thisFrame->frameControl = OSSwapBigToHostConstInt16(0x1000) * fc->subtype;
		}

		#ifdef DEBUG
		printf("----------------------------\n");
		printf("fc->type == %i\n",fc->type);
		printf("fc->subtype = %i\n",fc->subtype);
		printf("bssid: %.2X:%.2X:%.2X:%.2X:%.2X:%.2X\n", databuf[4], databuf[5], databuf[6], databuf[7], databuf[8], databuf[9]); // dest
		printf("source: %.2X:%.2X:%.2X:%.2X:%.2X:%.2X\n", databuf[10], databuf[11], databuf[12], databuf[13], databuf[14], databuf[15]);
		printf("dest: %.2X:%.2X:%.2X:%.2X:%.2X:%.2X\n", databuf[16], databuf[17], databuf[18], databuf[19], databuf[20], databuf[21]);
		#endif
	
	unsigned int framelen;
	
	if (thisFrame->dataLen < 2500) { // no buffer overflows please
		framelen = thisFrame->dataLen;
	} else {
		framelen = 2500;
		NSLog(@"Captured frame >2500 octets");
	}

		memcpy((frame + sizeof(WLFrame)), &databuf[24], framelen); // todo: limit this to 2500!
		noValidFrame = 0;
		stream_recv_bytes = 0;
		
		} //else {
			// printf("debug - somehow not a stream packet or too much data...  type %d recv %d\n", fhdr.frame_type, stream_recv_bytes);
		// }

		if (fhdr.frame_type != STREAM_FTYPE_PACKET && 
			fhdr.frame_type != STREAM_FTYPE_VERSION) {
			// Bail if we don't know the packet type
			NSLog(@"unknown frame type %d", fhdr.frame_type);

			// debug
			unsigned int x = 0;
			while (x < sizeof(struct stream_frame_header)) {
				printf("%02X ", ((uint8_t *) &fhdr)[x]);
				x++;
			}
			printf("\n");
			
			return NULL;
		}
	}
	return thisFrame; // finally!
}



#pragma mark -

-(bool) sendFrame:(UInt8*)f withLength:(int) size atInterval:(int)interval {
    return NO;
}

-(bool) stopSendingFrames {    
    return NO;
}

#pragma mark -

-(void) dealloc {
		NSLog(@"dealloc called");
    [super dealloc];
}

@end
