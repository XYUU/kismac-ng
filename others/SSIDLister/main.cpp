/*
        
        File:			main.cpp
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

#include <iostream>
#include "Screen.h"
#include "PacketSourcePCAP.h"
#include "PacketSourceUSB.h"
#include <pthread.h>
#include <curses.h>
#include <signal.h>

bool doParse, stillParsing; 
NetList n;
Screen *scr; PacketSource *ps;
pthread_mutex_t networksLock;
pthread_t data_thread;

static void finish(int sig);
static void resize(int sig);

void* parseData(void* p) {
	const unsigned char *data;
	int dataLen;
	Network *b, *b_old;
	
	while(doParse) {
		data = ps->getData(&dataLen);
		if (!data) break;
		
		pthread_mutex_lock(&networksLock);
			
		//get some data
		try {
			b = new Network(data, dataLen);
			b_old = n[b->bssid()];
			n[b->bssid()] = b;
			if (b_old) delete b_old;
			scr->setStatus("Found Network: " + b->bssid());
		} catch (NoNetwork_error) {
		}
		
		pthread_mutex_unlock(&networksLock);
	}
	
	stillParsing = false;
	
	return NULL;
}

int main (int argc, char * const argv[]) {
	
	if (argc < 2 || (strcmp("usb", argv[1]) != 0 && argc < 3)) {
		std::cerr << "Usage: " << argv[0] << " (pcap filename | pcaplive devicename | usb)\n";
		exit(-1);
	}
	
	if (!Network::test()) {
		std::cerr << "Internal Network test failed.\n";
		exit(-1);	
	}
	
	try {
		if (strcmp("usb", argv[1])) {
			ps = new PacketSourcePCAP(strcmp("pcaplive", argv[1]) == 0, argv[2]);
		} else {
#ifdef PacketSourceUSBAvailable
			ps = new PacketSourceUSB();
#else 
			std::cerr << "Prism USB support is not available on your system.\n";
			exit(-1);	
#endif
		}
	} catch (PacketSource_error e) {
		std::cerr << e.details << "\n";
		exit(-1);
	}
	
	pthread_mutex_init(&networksLock, NULL);
	
	scr = new Screen;
	scr->setNetworkList(&n);
	
	(void)signal(SIGINT, finish);      /* arrange interrupts to terminate */
	(void)signal(SIGWINCH, resize); 
	
	stillParsing= true;
	doParse = true;
	pthread_create(&data_thread, NULL, parseData, ps);

	scr->refreshScreen();
	
	while(stillParsing) {
		usleep(200);
		pthread_mutex_lock(&networksLock);
		scr->refreshScreen();
		pthread_mutex_unlock(&networksLock);
	}
	
	scr->setStatus("Capture completed.");
	scr->refreshScreen();
	getch();
	finish(0);
	
    return 0;
}

static void resize(int sig) {
	scr->handleResize();
}

static void finish(int sig) {
	doParse = false;
	pthread_cancel(data_thread);
	//while(stillParsing);
	
	delete scr;
	delete ps;
	
	pthread_mutex_destroy(&networksLock);
	
    exit(0);
}
