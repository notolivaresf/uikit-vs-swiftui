@import Cocoa;
#import <QuartzCore/QuartzCore.h>
#import "RoomController.h"
@interface CFAppDelegate : NSObject <NSApplicationDelegate>
@property CFRoomController *controller;
@property CFTimeInterval started;
@end
@implementation CFAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification { self.controller=[[CFRoomController alloc] initWithStartTime:self.started];[NSApp activateIgnoringOtherApps:YES];
    NSMenuItem *viewItem=[NSMenuItem new];viewItem.title=@"View";NSMenu *view=[NSMenu new];
    NSMenuItem *larger=[view addItemWithTitle:@"Increase Text Size" action:@selector(textLarger:) keyEquivalent:@"+"];larger.target=self.controller;
    NSMenuItem *actual=[view addItemWithTitle:@"Actual Text Size" action:@selector(resetTextSize:) keyEquivalent:@"0"];actual.target=self.controller;
    viewItem.submenu=view;[NSApp.mainMenu addItem:viewItem]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return YES; }
@end
int main(int argc,const char *argv[]) {
    CFTimeInterval start=CACurrentMediaTime();
    @autoreleasepool {
        NSApplication *app=[NSApplication sharedApplication];app.activationPolicy=NSApplicationActivationPolicyRegular;
        CFAppDelegate *delegate=[CFAppDelegate new];delegate.started=start;app.delegate=delegate;
        NSMenu *menu=[NSMenu new];NSMenuItem *item=[NSMenuItem new];[menu addItem:item];NSMenu *appMenu=[NSMenu new];[appMenu addItemWithTitle:@"About Campfire" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];[appMenu addItem:NSMenuItem.separatorItem];[appMenu addItemWithTitle:@"Quit Campfire" action:@selector(terminate:) keyEquivalent:@"q"];item.submenu=appMenu;
        NSMenuItem *editItem=[NSMenuItem new];editItem.title=@"Edit";[menu addItem:editItem];NSMenu *edit=[NSMenu new];[edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];[edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];editItem.submenu=edit;app.mainMenu=menu;
        [app run];
    }return 0;
}
