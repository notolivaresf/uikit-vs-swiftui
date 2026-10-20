@import UIKit;
#import "CFAppDelegate.h"
#import "CFLaunch.h"

int main(int argc, char *argv[]) {
    CFLaunchStart = NSProcessInfo.processInfo.systemUptime;
    CFLaunchBeginLoadingDataset();
    NSString *appDelegateClassName;
    @autoreleasepool {
        appDelegateClassName = NSStringFromClass([CFAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
