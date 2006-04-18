//
//  PrefsAdvanced.h
//  KisMAC
//
//  Created by themacuser on Mon Apr 3 2006.
//

#import "PrefsAdvanced.h"
#import "WaveHelper.h"

@implementation PrefsAdvanced

-(void)updateUI {
    if ([controller objectForKey:@"ac_ff"] == nil) {
        [self setDefaults:self];
        return;
    }
    [ac_ff setStringValue:[controller objectForKey:@"ac_ff"]];
	[bf_interval setStringValue:[controller objectForKey:@"bf_interval"]];
	[bpfdevice setStringValue:[controller objectForKey:@"bpfdevice"]];
	[bpfloc setStringValue:[controller objectForKey:@"bpfloc"]];
	[pr_interval setStringValue:[controller objectForKey:@"pr_interval"]];
}

-(BOOL)updateDictionary {
	[controller setObject:[ac_ff stringValue] forKey:@"ac_ff"];
	[controller setObject:[bf_interval stringValue] forKey:@"bf_interval"];
	[controller setObject:[bpfdevice stringValue] forKey:@"bpfdevice"];
	[controller setObject:[bpfloc stringValue] forKey:@"bpfloc"];
	[controller setObject:[pr_interval stringValue] forKey:@"pr_interval"];
    return YES;
}

-(IBAction)setValueForSender:(id)sender {
   if(sender == ac_ff) {
	[controller setObject:[ac_ff stringValue] forKey:@"ac_ff"];
    } else if(sender == bf_interval) {
		[controller setObject:[bf_interval stringValue] forKey:@"bf_interval"];
    } else if(sender == bpfdevice) {
		[controller setObject:[bpfdevice stringValue] forKey:@"bpfdevice"];
    } else if(sender == bpfloc) {
		[controller setObject:[bpfloc stringValue] forKey:@"bpfloc"];
    } else if(sender == pr_interval) {
       [controller setObject:[pr_interval stringValue] forKey:@"pr_interval"];
	} else {
        NSLog(@"Error: Invalid sender(%@) in setValueForSender:",sender);
    }
}

-(IBAction)setDefaults:(id)sender {
	[ac_ff setStringValue:@"2"];
	[bf_interval setStringValue:@"0.1"];
	[bpfdevice setStringValue:@"wlt1"];
	[bpfloc setStringValue:@"/dev/bpf0"];
	[pr_interval setStringValue:@"100"];
}

@end