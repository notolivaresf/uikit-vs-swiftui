#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import "CFAppDelegate.h"
#import "CFRoomController.h"

// Time of the first line of the app's own code, for the launch figure in the benchmark bar.
CFTimeInterval CFLaunchStart;

int main(int argc, const char *argv[]) {
    CFLaunchStart = CACurrentMediaTime();
    @autoreleasepool {
        [CFRoomController preloadDataset];
        NSApplication *app = NSApplication.sharedApplication;
        CFAppDelegate *delegate = [[CFAppDelegate alloc] init];
        app.delegate = delegate;
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        [app run];
    }
    return 0;
}
