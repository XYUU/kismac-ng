#import "GraphView.h"

struct graphStruct data;
int graphLength;

@implementation GraphView

- (void)initialize {

    _currentMode = trafficData;
    justSwitchedDataType = NO;

    _grid = [[BIGLLineView alloc] initWithLines:[NSArray array]];
    [_grid setLocation: NSMakePoint(30,30)];
    [_grid setLineWidth:0.5];
    _gridFrame = [[BIGLLineView alloc] initWithLines:[NSArray array]];
    [_gridFrame setLineWidth:2];

    _zeroLabel = [[BIGLTextView alloc] init];
    [_zeroLabel setLocation: NSMakePoint(15,8)];
    _maxLabel = [[BIGLTextView alloc] init];
    _curLabel = [[BIGLTextView alloc] init];
    _legend = [[BIGLImageView alloc] init];
    [_legend setVisible:NO];
    
    _graphs = [[NSMutableArray array] retain];
    
    [self setBackgroundColor:[NSColor blackColor]];
    [self setGridColor:[NSColor colorWithCalibratedRed:96.0/255.0 green:123.0/255.0 blue:173.0/255.0 alpha:1]];

    zoomLock = [[NSLock alloc] init];
    
    vScale = 0;
    dvScale = 0;
    maxLength = 0;
    gridNeedsRedrawn = NO;
    
    c1 = [[NSColor greenColor] retain];
    c2 = [[NSColor redColor] retain];
}


-(void)awakeFromNib {
    [self initialize];

    // default to 30-second interval
    scanInterval = 0.25;
    maxLength = (int)(30.0 / scanInterval);
    [self setTimeLength:_intervalButton];
    [self setCurrentMode:_modeButton];
    
    [self addSubView:_grid];
    [_grid addSubView:_gridFrame];
    [self addSubView:_zeroLabel];
    [self addSubView:_maxLabel];
    [self addSubView:_curLabel];
    [self addSubView:_legend];
   
    [self updateGraph];
}


#pragma mark -

- (void)setGridColor:(NSColor *)newColor {
    [_grid      setColor:newColor];
    [_gridFrame setColor:newColor];
}

- (IBAction)setTimeLength:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:[sender indexOfSelectedItem] forKey:@"GraphTimeInterval"];

    maxLength = (int)ceil([[sender selectedItem] tag] / scanInterval);
    gridNeedsRedrawn = YES;
    
    [self performSelectorOnMainThread:@selector(resized:) withObject:nil waitUntilDone:YES];
}

- (IBAction)setCurrentMode:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:[sender indexOfSelectedItem] forKey:@"GraphMode"];

    justSwitchedDataType = YES;
    _currentMode = [sender indexOfSelectedItem];
    if(_currentMode != trafficData && _currentMode != packetTransData && _currentMode != respTimeData)
        _currentMode = trafficData;

    [self performSelectorOnMainThread:@selector(resized:) withObject:nil waitUntilDone:YES];
}

- (void)outputTIFFTo:(NSString*)file {
    NSRect rect = [self frame];
    rect.origin = NSZeroPoint;
    
    [[self dataWithTIFFInsideRect:rect] writeToFile:file atomically:YES];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateGraph];
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    [self updateGraph];
}

- (void)resized:(NSNotification*)note {
    [self updateGraph];
}

#pragma mark -

- (void)updateDataForRect:(NSRect)rect {
    int i, current;
    unsigned int j;
    
    // setup graph rect with nice margins
    graphRect = rect;
    graphRect.origin.x = 30;
    graphRect.origin.y = 30;
    graphRect.size.width -= 60;
    graphRect.size.height -= 60;

    length = graphLength;
    if(length > maxLength) {
        offset = length - maxLength;
        length = maxLength;
    }
    else {
        offset = 0;
    }

    aMaximum=0;
    memset(buffer,0,MAX_YIELD_SIZE * sizeof(int));

    // find the biggest point on our graph
    for (i = 0 ; i < length ; i++) {
        current = 0;
        switch(_currentMode) {
            case trafficData:
                current += data.trafficData[i + offset];
                break;
            case packetTransData:
                current += data.packetTransData[i + offset];
                break;
            case respTimeData:
                current += data.respTimeData[i + offset];
                break;
        }
        buffer[i] = current;
        if (current > aMaximum)
            aMaximum = current;
    }
    

    // a horizontal line for every 5 seconds
    stepx = graphRect.size.width / maxLength / scanInterval * 5;

    dvScale = graphRect.size.height / (1.2 * aMaximum);
    if(!vScale)
        vScale = dvScale;
    if(dvScale != vScale) {
        if(justSwitchedDataType) {
            justSwitchedDataType = NO;
            vScale = dvScale;
        }
        else {
            [NSThread detachNewThreadSelector:@selector(zoomThread:) toTarget:self withObject:nil];
        }
    }

    // a vertical line for every 512 bytes
    stepy = 500 * vScale * scanInterval;
}

- (void)updateGraph {
    // do some math...
    [self updateDataForRect:[self frame]];
    
    // do the drawing...
    [self drawGridInRect:graphRect];
    [self drawGraphInRect:graphRect];
    [self drawGridLabelForRect:[self frame]];
    [self drawLegendForRect:graphRect];
    [self setNeedsDisplay:YES];
}

- (void)drawGridInRect:(NSRect)rect {
    static float lastVScale = 0.0;
    static NSRect lastRect; // = NSMakeRect(0,0,0,0);
    NSMutableArray *a;
    int i = 0;
    int count = 0;
    int multiple = 0;
    float curY, curX;
    
    if(lastVScale == vScale && NSEqualRects(lastRect,rect)
       && !gridNeedsRedrawn) {
        gridNeedsRedrawn = NO;
        return;
    }

    // if we get here, then the grid needs to be redrawn
    lastVScale = vScale;
    lastRect = rect;
    a = [NSMutableArray array];
    
    count = (int)ceil(rect.size.height / stepy);
    if(count >= 20) {
        multiple = 2;		// show a line each 1kb
        if(count >= 100)
            multiple = 10;	// show a line very 5kb
        if(count >= 200)
            multiple = 20;	// show a line very 10kb
    }
    for(i = 0 ; i * stepy < rect.size.height ; i++) {
        if(multiple && i % multiple)
            continue;
        curY = (i * stepy);
        if (curY < rect.size.height) {
            [a addObject:[NSNumber numberWithFloat:0.5]];
            [a addObject:[NSNumber numberWithFloat:curY]];
            [a addObject:[NSNumber numberWithFloat:rect.size.width]];
            [a addObject:[NSNumber numberWithFloat:curY]];
        }
    }
    multiple = 0;

    count = (int)ceil(rect.size.width / stepx);
    if(count >= 60) {
        multiple = 12;		// show a line each minute
        if(count >= 720)
            multiple = 120;	// show a line very 5 minutes
    }
    for (i = 0 ; i < count ; i++) {
        if(multiple && i % multiple)
            continue;
        curX = (i * stepx);
        if (curX < rect.size.width) {
            [a addObject:[NSNumber numberWithFloat:curX]];
            [a addObject:[NSNumber numberWithFloat:0.5]];
            [a addObject:[NSNumber numberWithFloat:curX]];
            [a addObject:[NSNumber numberWithFloat:rect.size.height]];
        }
    }
    [_grid setLines:a];
    
    a = [NSMutableArray array];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.height+1]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.height+1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.width+2]];
    [a addObject:[NSNumber numberWithFloat:rect.size.height+1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.width+2]];
    [a addObject:[NSNumber numberWithFloat:rect.size.height+1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.width+2]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:rect.size.width+2]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [a addObject:[NSNumber numberWithFloat:-1]];
    [_gridFrame setLines:a];
}

- (void)drawGraphInRect:(NSRect)rect {
    int i, *ptr;
    unsigned int n;
    BIGLGraphView *curView;
    NSMutableArray *a;
    int count = (_currentMode == packetTransData) ? 2 : 1;
    
    while ([_graphs count] < count) {
        [_graphs addObject:[[BIGLGraphView alloc] init]];
        [[_graphs lastObject] setLocation:NSMakePoint(31,31)];
        [(BIGLSubView*)[_graphs lastObject] setVisible:YES];
        [self addSubView:[_graphs lastObject]];
        [[_graphs lastObject] autorelease];
    }
    
    for(n = 0 ; n < count; n++) {
        float width = rect.size.width;
        float height;
        
        switch(_currentMode) {
            case trafficData:
                ptr = data.trafficData;
                break;
            case packetTransData:
                if (n == 1) ptr = data.packetTransData;
                else ptr = data.packetRecData;
                break;
            case respTimeData:
                ptr = data.respTimeData;
                break;
            default:
                ptr = data.trafficData;
        }
        
        curView = [_graphs objectAtIndex:n];
        a = [NSMutableArray arrayWithCapacity:length];
        stepx=(rect.size.width) / maxLength;
        
        for(i = 0 ; i < length ; i++) {
            height = buffer[i] * vScale;
            if (height > rect.size.height) height = rect.size.height;
            [a addObject:[NSNumber numberWithFloat:width - (((float)(length - i)) * stepx)]];
            [a addObject:[NSNumber numberWithFloat:height]];
        }
        i--;
        
        [a addObject:[NSNumber numberWithFloat:width]];
        [a addObject:[NSNumber numberWithFloat:buffer[i] * vScale]];
        [curView setGraph:a];
        
        NSColor *c = [(_currentMode == packetTransData && n == 1) ? c2 : c1 copy];
        [curView setColor:[c autorelease]];

        for(i = 0 ; i < length ; i++) {
            buffer[i] -= ptr[i + offset];
        }
    }
    
    if (count == 1 && [_graphs count] == 2)
        [(BIGLSubView*)[_graphs objectAtIndex:1] setVisible:NO];
        
}

- (void)drawGridLabelForRect:(NSRect)rect {
    // draws the text, giving a numerical value to the graph
    unsigned int j;
    int current = 0, max = 0;
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSString *zeroStr, *currentStr, *maxStr;

    if(length) {
        switch(_currentMode) {
            case trafficData:
                current += (int)(data.trafficData[length - 2 + offset] / scanInterval);
                break;
            case packetTransData:
                current += (int)(data.packetTransData[length - 2 + offset] / scanInterval);
                break;
            case respTimeData:
                current += (int)(data.respTimeData[length - 2 + offset]);
                break;
        }
    }

    if (_currentMode!=respTimeData)
        max = (int)(aMaximum * 1.1 / scanInterval);
    else
        max = (int)(aMaximum * 1.1);
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:[NSColor colorWithCalibratedRed:96.0/255.0 green:123.0/255.0 blue:173.0/255.0 alpha:1] forKey:NSForegroundColorAttributeName];

    switch(_currentMode) {
        case trafficData:
            zeroStr = @"0 bps";
            currentStr = [self stringForBytes:current];
            maxStr = [self stringForBytes:max];
            break;
        case packetTransData:
            zeroStr = @"0 packets";
            currentStr = [self stringForPackets:current];
            maxStr = [self stringForPackets:max];
            break;            
        case respTimeData:
            zeroStr = @"0 signal";
            currentStr = [self stringForRespTime:current];
            maxStr = [self stringForRespTime:max];
            break;            
        default:
            zeroStr = @"0 bps";
            currentStr = [self stringForBytes:current];
            maxStr = [self stringForBytes:max];
            break;
    }
    
    
    [_zeroLabel setString:zeroStr    withAttributes:attrs];
    [_maxLabel  setString:maxStr     withAttributes:attrs];
    [_curLabel  setString:currentStr withAttributes:attrs];
    
    [_maxLabel setLocation: NSMakePoint(15,rect.size.height - 5 - [textFont boundingRectForFont].size.height)];
    [_curLabel setLocation: NSMakePoint(rect.size.width - 15 - [textFont widthOfString:currentStr], 8)];
}

- (void)drawLegendForRect:(NSRect)rect {
        [_legend setVisible:NO];
        return;
}

#pragma mark -

- (NSString*)stringForBytes:(int)bytes {
    if(bytes < 1024)
        return [NSString stringWithFormat:@"%d bps",bytes];
    else
        return [NSString stringWithFormat:@"%.2f kbps",(float)bytes / 1024];
}

- (NSString*)stringForPackets:(int)bytes {
    return [NSString stringWithFormat:@"%d %@", bytes, NSLocalizedString(@"packets/sec", "label of traffic view")];
}

- (NSString*)stringForRespTime:(int)bytes {
    return [NSString stringWithFormat:@"%d ms %@", bytes, NSLocalizedString(@"resp. time", "label of traffic view")];
}

#pragma mark -


- (void)zoomThread:(id)object {
    NSAutoreleasePool* subpool = [[NSAutoreleasePool alloc] init];

    int i;
    int fps = 30;
    int frames = (int)floor((float)fps * scanInterval);
    float delta = (dvScale - vScale) / (float)frames;

    if([zoomLock tryLock]) {
        //NSLog(@"ZOOMING: frames = %d, delta = %f",frames,delta);    
        for(i = 0 ; i < frames ; i++) {
            vScale += delta;
            [self performSelectorOnMainThread:@selector(resized:) withObject:nil waitUntilDone:YES];
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:scanInterval / frames]];
        }
        vScale = dvScale;
        [zoomLock unlock];
    }
    else {
        //NSLog(@"ZOOM LOCK IS LOCKED!");
    }
    
    [subpool release];
}


#pragma mark -

- (void)dealloc {
    [c1 release];
    [c2 release];
    
    [_grid release];
    
    [_graphs release];
    [_grid release];
    [_gridFrame release];
    [_zeroLabel release];
    [_curLabel release];
    [_maxLabel release];
    [_legend release];
    
    [zoomLock release];
    [super dealloc];
}



@end
