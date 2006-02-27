/* GrowlController */

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>
#import "WavePacket.h"

@interface GrowlController : NSObject<GrowlApplicationBridgeDelegate> {
}
- (void)registerGrowl;
+ (void)notifyGrowlOpenNetwork:(NSString *)notname SSID:(NSString *)SSID BSSID:(NSString *)BSSID signal:(int)signal channel:(int)channel;
+ (void)notifyGrowlUnknownNetwork:(NSString *)notname SSID:(NSString *)SSID BSSID:(NSString *)BSSID signal:(int)signal channel:(int)channel;
+ (void)notifyGrowlLEAPNetwork:(NSString *)notname SSID:(NSString *)SSID BSSID:(NSString *)BSSID signal:(int)signal channel:(int)channel;
+ (void)notifyGrowlWEPNetwork:(NSString *)notname SSID:(NSString *)SSID BSSID:(NSString *)BSSID signal:(int)signal channel:(int)channel;
+ (void)notifyGrowlWPANetwork:(NSString *)notname SSID:(NSString *)SSID BSSID:(NSString *)BSSID signal:(int)signal channel:(int)channel;
+ (void)notifyGrowlProbeRequest:(NSString *)notname BSSID:(NSString *)BSSID signal:(int)signal;
+ (void)notifyGrowlStartScan;
+ (void)notifyGrowlStopScan;
@end
