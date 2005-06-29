/*
        
        File:			Screen.cpp
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

#include "Screen.h"
#include <curses.h>

Screen::Screen() {
	initscr();      /* initialize the curses library */
	noecho();       /* don't echo input */
	
	if (has_colors()) {
		start_color();
		init_pair(COLOR_RED, COLOR_RED, COLOR_BLACK);
		init_color(COLOR_RED, 20, 20, 20);
	}
}

void Screen::printAtPoint(const char *data, int xpos, int ypos) {
	int x, y;
	getbegyx(stdscr, x, y);
	
	mvprintw(ypos + y, xpos + x, data);
} 

void Screen::setNetworkList(NetList *n) {
	_netList = n;
}

void Screen::setStatus(std::string status) {
	char *str;
	int length = getmaxx(stdscr);
	
	str = new char[length + 1];
	memset(str, ' ', length);
	str[length] = 0;
	printAtPoint(str, 0, 1);
	delete [] str;
	
	_status = status;
}

void Screen::refreshScreen() {
	int lenSSID = 32 + 2, lenBSSID = 18 + 2;
	NetList::const_reverse_iterator it;
		
	//draw program and version
	attrset(A_BOLD);
	printAtPoint("SSIDLister 0.1a", 0, 0);
	
	//draw header
	printAtPoint("BSSID", 1, 2);
	printAtPoint("SSID", lenBSSID + 1, 2);
	printAtPoint("Encryption", lenSSID + lenBSSID + 1, 2);
	
	if (_status.length() > 0) {
		attrset(COLOR_PAIR(COLOR_RED) | A_BOLD);
		printAtPoint(_status.c_str(), getmaxx(stdscr) - _status.length() - 1, 1);
	}
	
	//draw the networks
	attrset(A_NORMAL);
	Network *n;
	std::list<std::string> l;
	int k = 4;
	
	it = _netList->rbegin();
	for (int i = 0; i < _netList->size(); i++) {
		n = (*it).second;
		l = n->description();
		for (int j = l.size(); j > 0; j--) {
			printAtPoint(l.front().c_str(), 1, k++);
			l.pop_front();
			if (k >= getmaxy(stdscr)) break;
		}
		if (k >= getmaxy(stdscr)) break;
		it++;
	}
	
	//draw table
	attrset(A_DIM);
	mvvline(2, lenBSSID - 1, ACS_BLOCK, getmaxy(stdscr));
	mvvline(2, lenSSID + lenBSSID - 1, ACS_BLOCK, getmaxy(stdscr));
	mvhline(3, 0, ACS_BLOCK, getmaxx(stdscr));
	attroff(A_DIM);
	
	//move the cursor down
	move(getmaxy(curscr) - 1, getmaxx(curscr) - 1);
	
	refresh();
}

void Screen::handleResize() {
	endwin();
	refresh();
	refreshScreen();
}

Screen::~Screen() {
	clear();
    endwin();
}
