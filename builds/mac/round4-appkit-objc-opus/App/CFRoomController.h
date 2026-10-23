#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

// Owns the window, the data (CampfireKitObjC) and the room's scroll position rules.
@interface CFRoomController : NSObject <NSWindowDelegate>

// Starts generating the dataset in the background (call first thing at launch).
+ (void)preloadDataset;

- (instancetype)initWithBenchmarkBar:(BOOL)benchmark launchStart:(CFTimeInterval)launchStart;
- (void)showWindow;

// View menu: the app's own text size.
- (IBAction)makeTextBigger:(nullable id)sender;
- (IBAction)makeTextSmaller:(nullable id)sender;
- (IBAction)makeTextStandardSize:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
