/* Controller */

#import <Cocoa/Cocoa.h>
#import "GraphView.h"

@interface Controller : NSObject
{
    BOOL            _flooding;
    int             _socket;
    unsigned int    _sent, _recv;
    float           _minResp, _maxResp;
    double          _bytes, _respTime;
    double          _validDelay;
    int             _validPacketCount, _validPacketSize;
    int				_totalPackets;
	
    IBOutlet NSTextField *_delay;
    IBOutlet id _floodButton;
    IBOutlet GraphView *_graph;
    IBOutlet NSTextField *_packetCount;
    IBOutlet NSTextField *_packetSize;
    IBOutlet NSTextField *_server;
}

- (IBAction)flood:(id)sender;
- (IBAction)changeValue:(id)sender;
- (IBAction)captureScreen:(id)sender;

@end
