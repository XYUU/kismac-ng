#import "Controller.h"
#include <sys/select.h> 
#include <sys/socket.h> 
#include <netinet/in.h> 
#include <sys/types.h> 
#include <netdb.h> 

@implementation Controller

- (void)recv:(NSObject*)obj {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    struct sockaddr_in addr; 
    UInt8 buffer[65536];
    int size = 65536, v, addr_len;
    UnsignedWide *rec, cur;
    float t;

    [NSThread setThreadPriority:1.0];
    
    while (YES) {
        addr_len = sizeof(addr);
        
        if ((v = recvfrom(_socket, buffer, size, 0, (struct sockaddr *)&addr, &addr_len)) >= sizeof(rec)) {
            Microseconds(&cur);
            _bytes += v;
            _recv++; _totalPackets++;
            rec = (UnsignedWide*)buffer;
            t = (cur.lo - rec->lo) / 1000.0;
            if (t < _minResp) _minResp = t;
            if (t > _maxResp) _maxResp = t;
            _respTime += t;
        }
    } 

ret:
    [pool release];
    return;

err:
    [self flood:self];
    goto ret;
}

- (void)send:(NSObject*)obj {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *a = [[_server stringValue] componentsSeparatedByString:@":"];
    struct sockaddr_in addr; 
    struct hostent *hp;
    UInt8 buffer[65536];
    unsigned int i = 0;

    [NSThread setThreadPriority:1.0];
    
    memset(buffer, 0, sizeof(buffer));
    if ([a count] != 2) goto err;
        
    NSString *server = [a objectAtIndex:0];
    int port = [[a lastObject] intValue];
    
    if (port == 0) goto err;
    if ((hp = gethostbyname([server cString])) == NULL) goto err;
    
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    memcpy(&addr.sin_addr, hp->h_addr, hp->h_length);
    addr.sin_port = htons(port);
    
    while (_flooding) {
        if (_validPacketCount != 0 && _validPacketCount <= i) goto err;
        Microseconds((UnsignedWide*)buffer);
        sendto(_socket, buffer, _validPacketSize, 0, (struct sockaddr *)&addr, sizeof(addr));
        i++;
        if ([_delay intValue]) {
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow: _validDelay]];
        }
        _sent++;
    }
    
ret:
    [pool release];
    return;

err:
    NSBeep();
    [self flood:self];
    goto ret;
}

- (void)sweep:(NSTimer*)timer {
    data.trafficData[graphLength] = _bytes;
    data.packetTransData[graphLength] = _sent;
    if (_recv) data.respTimeData[graphLength] = _respTime / _recv;
    else data.respTimeData[graphLength] = 0;
    data.packetRecData[graphLength] = _recv;
    graphLength++;
    
    _bytes = _sent = _respTime = _recv = 0;
    
    if(graphLength >= MAX_YIELD_SIZE) {
        memcpy(data.trafficData,data.trafficData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        data.trafficData[MAX_YIELD_SIZE] = 0;

        memcpy(data.packetTransData,data.packetTransData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        data.packetTransData[MAX_YIELD_SIZE] = 0;

        memcpy(data.respTimeData,data.respTimeData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        data.respTimeData[MAX_YIELD_SIZE] = 0;

        memcpy(data.packetRecData,data.packetRecData + 1, (MAX_YIELD_SIZE) * sizeof(int));
        data.packetRecData[MAX_YIELD_SIZE] = 0;
    }
    [_graph updateGraph];
    
    if (!_flooding) {
        [timer invalidate];
        if (_totalPackets) {
			NSBeginInformationalAlertSheet(@"UDP Flood beendet", nil, nil, nil, [NSApp mainWindow], self, nil, nil, nil, @"Statistik:\n\tminimale Antwortzeit: %3.0f ms\n\tmaximale Antwortzeit: %3.0f ms\n\tEmpfangene Packete: %d", _minResp, _maxResp, _totalPackets);
		} else {
			NSBeginInformationalAlertSheet(@"UDP Flood beendet", nil, nil, nil, [NSApp mainWindow], self, nil, nil, nil, @"Es wurden keine Antworten empfangen.");
		}
    }
}

- (IBAction)flood:(id)sender {
    struct sockaddr_in addr;
    [_server setEnabled:_flooding];
    _flooding = !_flooding;
        
    [_floodButton setState: _flooding ? NSOnState : NSOffState];
    if (_flooding) {
        _maxResp = 0;
        _minResp = 0xFFFFFFFF;
        if ([_packetSize  intValue] == 0) [_packetSize  setIntValue:64];
        if ([_packetCount intValue] == 0) [_packetCount setIntValue:0];
        if ([_delay intValue] == 0)       [_delay setIntValue:0];
        if ([[_server stringValue] length] < 3) [_server setStringValue:@"nil.prakinf.tu-ilmenau.de:12345"];
        [self changeValue:_packetSize]; [self changeValue:_packetCount]; [self changeValue:_delay];
        
        if (!_socket) {
            _socket = socket(AF_INET, SOCK_DGRAM, 0);
            if (_socket == -1) return;
            memset(&addr, 0, sizeof(addr));
            addr.sin_family = AF_INET;
            addr.sin_addr.s_addr = INADDR_ANY;
            addr.sin_port = htons(12345);
            if (bind(_socket, (struct sockaddr *)&addr, sizeof(addr)) == -1) return;
            [NSThread detachNewThreadSelector:@selector(recv:)  toTarget:self withObject:nil];
        }
		_totalPackets = 0;
        [NSThread detachNewThreadSelector:@selector(send:)  toTarget:self withObject:nil];
        [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(sweep:) userInfo:nil repeats:YES];
    }
}

- (IBAction)changeValue:(id)sender {
    if (sender == _packetSize) {
        if ([_packetSize intValue] > sizeof(UnsignedWide)) {
            if ([_packetSize intValue] < 60000) _validPacketSize = [_packetSize intValue];
            else [_packetSize setIntValue:60000];
        } else [_packetSize setIntValue:64];
    } else if (sender == _packetCount) {
        _validPacketCount = [_packetCount intValue];
    } else if (sender == _delay) {
        _validDelay = [_delay doubleValue] / 1000.0;
    }
}

@end
