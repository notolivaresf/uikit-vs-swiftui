#import "CFAppDelegate.h"
#import "CFRoomViewController.h"

@implementation CFAppDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session
                              options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *c = [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:session.role];
    c.delegateClass = [CFSceneDelegate class];
    return c;
}

@end

@implementation CFSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) { return; }
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.rootViewController = [[CFRoomViewController alloc] init];
    self.window = window;
    [window makeKeyAndVisible];
}

@end
