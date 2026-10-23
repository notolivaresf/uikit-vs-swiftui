#import "CFAppDelegate.h"
#import "CFRoomController.h"

extern CFTimeInterval CFLaunchStart;

@implementation CFAppDelegate {
    CFRoomController *_controller;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // Never bring back an earlier window size or position.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSQuitAlwaysKeepsWindows"];
    BOOL benchmark = [[NSUserDefaults standardUserDefaults] boolForKey:@"uvsBenchmark"];
    _controller = [[CFRoomController alloc] initWithBenchmarkBar:benchmark launchStart:CFLaunchStart];
    [self buildMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [_controller showWindow];
    [NSApp activate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)buildMenu {
    NSMenu *main = [[NSMenu alloc] init];
    NSString *name = NSProcessInfo.processInfo.processName;

    NSMenu *app = [[NSMenu alloc] initWithTitle:name];
    [app addItemWithTitle:[@"About " stringByAppendingString:name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:[@"Hide " stringByAppendingString:name] action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *others = [app addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    others.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [app addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:[@"Quit " stringByAppendingString:name] action:@selector(terminate:) keyEquivalent:@"q"];
    [main addItemWithTitle:name action:nil keyEquivalent:@""].submenu = app;

    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [main addItemWithTitle:@"Edit" action:nil keyEquivalent:@""].submenu = edit;

    NSMenu *view = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *bigger = [view addItemWithTitle:@"Bigger Text" action:@selector(makeTextBigger:) keyEquivalent:@"+"];
    bigger.target = _controller;
    NSMenuItem *bigger2 = [view addItemWithTitle:@"Bigger Text" action:@selector(makeTextBigger:) keyEquivalent:@"="];
    bigger2.target = _controller;
    bigger2.alternate = NO;
    bigger2.hidden = YES;
    bigger2.allowsKeyEquivalentWhenHidden = YES;
    NSMenuItem *smaller = [view addItemWithTitle:@"Smaller Text" action:@selector(makeTextSmaller:) keyEquivalent:@"-"];
    smaller.target = _controller;
    NSMenuItem *actual = [view addItemWithTitle:@"Actual Size" action:@selector(makeTextStandardSize:) keyEquivalent:@"0"];
    actual.target = _controller;
    [main addItemWithTitle:@"View" action:nil keyEquivalent:@""].submenu = view;

    NSMenu *window = [[NSMenu alloc] initWithTitle:@"Window"];
    [window addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [window addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [main addItemWithTitle:@"Window" action:nil keyEquivalent:@""].submenu = window;
    NSApp.windowsMenu = window;

    NSApp.mainMenu = main;
}

@end
