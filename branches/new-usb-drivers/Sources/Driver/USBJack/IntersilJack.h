//
//  IntersilJack.h
//  KisMAC
//
//  Created by Geoffrey Kruse on 5/1/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "USBJack.h"

class IntersilJack: public USBJack
{
public:

    IntersilJack();
    ~IntersilJack();
    
    IOReturn    _init();
    IOReturn    _reset();
    
    bool    startCapture(UInt16 channel);
    bool    stopCapture();
    bool    getChannel(UInt16* channel);
    bool    getAllowedChannels(UInt16* channel);
    bool    setChannel(UInt16 channel);
    int     WriteTxDescriptor(WLFrame * theFrame);
    
    
private:
        int temp;
};


