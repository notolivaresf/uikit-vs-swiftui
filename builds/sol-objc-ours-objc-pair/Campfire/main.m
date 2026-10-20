@import UIKit;
#import "CFRoomController.h"
CFTimeInterval CFLaunchTime;
@interface CFAppDelegate : UIResponder <UIApplicationDelegate>
@end
@interface CFSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation CFAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Campfire" sessionRole:session.role];
    configuration.delegateClass = CFSceneDelegate.class;
    return configuration;
}
@end
@implementation CFSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [CFRoomController new];
    [self.window makeKeyAndVisible];
}
@end
int main(int argc, char *argv[]) {
    CFLaunchTime = CACurrentMediaTime();
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(CFAppDelegate.class)); }
}
