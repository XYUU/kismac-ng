/* GraphView */

#import <Cocoa/Cocoa.h>
#import <BIGL/BIGL.h>

#define MAX_YIELD_SIZE (int)1200

enum {
    trafficData,
    packetTransData,
    respTimeData,
    packetRecData
};

struct graphStruct {
    int trafficData[MAX_YIELD_SIZE + 1];
    int packetTransData[MAX_YIELD_SIZE + 1];
    int respTimeData[MAX_YIELD_SIZE + 1];
    int packetRecData[MAX_YIELD_SIZE + 1];
};

extern struct graphStruct data;
extern int graphLength;

@interface GraphView : BIGLView
{
    IBOutlet NSPopUpButton  *_intervalButton;
    IBOutlet NSPopUpButton  *_modeButton;
    
    NSMutableArray          *_graphs;
    
    BIGLLineView            *_grid, *_gridFrame;
    BIGLTextView            *_zeroLabel, *_maxLabel, *_curLabel;
    BIGLImageView           *_legend;
    
    NSLock* zoomLock;

    NSColor *_backgroundColor;

    NSRect graphRect;
    NSTimeInterval scanInterval;
    float vScale;	// used for the vertical scaling of the graph
    float dvScale;	// used for the sweet 'zoom' in/out
    float stepx;	// step for horizontal lines on grid
    float stepy;	// step for vertical lines on grid
    float aMaximum;	// maximum bytes received
    int buffer[MAX_YIELD_SIZE];
    BOOL gridNeedsRedrawn;

    BOOL justSwitchedDataType;
    int _legendMode;
    int length;
    int offset;
    int maxLength;
    int _currentMode;
    NSColor *c1, *c2;
}

- (void)outputTIFFTo:(NSString*)file;

- (IBAction)setTimeLength:(id)sender;
- (IBAction)setCurrentMode:(id)sender;

- (void)setGridColor:(NSColor *)newColor;

- (void)updateGraph;
- (void)updateDataForRect:(NSRect)rect;
- (void)drawGraphInRect:(NSRect)rect;
- (void)drawGridInRect:(NSRect)rect;
- (void)drawGridLabelForRect:(NSRect)rect;
- (void)drawLegendForRect:(NSRect)rect;

- (NSString*)stringForBytes:(int)bytes;
- (NSString*)stringForPackets:(int)bytes;
- (NSString*)stringForRespTime:(int)bytes;

@end
