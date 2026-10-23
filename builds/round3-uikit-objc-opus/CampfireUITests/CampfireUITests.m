@import XCTest;

/// Parsed debug-bar state label: `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`.
@interface CFState : NSObject
@property (nonatomic) NSInteger first, last, loaded, top, ms;
@property (nonatomic) BOOL pinned;
@property (nonatomic) double y;
@property (nonatomic, copy) NSString *raw;
@end
@implementation CFState
@end

@interface CampfireUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation CampfireUITests

- (void)setUp {
    self.continueAfterFailure = NO;
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    self.app = [[XCUIApplication alloc] init];
    self.app.launchArguments = @[@"-uvsBenchmark", @"YES"];
    [self.app launch];
    XCTAssertTrue([[self stateElement] waitForExistenceWithTimeout:5]);
}

- (void)tearDown {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
}

- (XCUIElement *)stateElement {
    return self.app.staticTexts[@"debug.state"];
}

- (CFState *)state {
    NSString *text = [self stateElement].label;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"^first (\\d+) last (\\d+) loaded (\\d+) pinned (yes|no) top (\\d+) y (-?\\d+\\.\\d) ms (\\d+)$" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    XCTAssertNotNil(m, @"state label has the wrong format: %@", text);
    CFState *s = [[CFState alloc] init];
    s.raw = text;
    if (!m) { return s; }
    NSString *(^g)(NSUInteger) = ^NSString *(NSUInteger i) { return [text substringWithRange:[m rangeAtIndex:i]]; };
    s.first = g(1).integerValue;
    s.last = g(2).integerValue;
    s.loaded = g(3).integerValue;
    s.pinned = [g(4) isEqualToString:@"yes"];
    s.top = g(5).integerValue;
    s.y = g(6).doubleValue;
    s.ms = g(7).integerValue;
    return s;
}

- (void)tap:(NSString *)title {
    [self.app.buttons[title] tap];
}

- (void)settle {
    [NSThread sleepForTimeInterval:0.6];
}

- (void)testLaunchState {
    CFState *s = [self state];
    XCTAssertEqual(s.first, 49961);
    XCTAssertEqual(s.last, 50000);
    XCTAssertEqual(s.loaded, 40);
    XCTAssertTrue(s.pinned);
    XCTAssertGreaterThan(s.ms, 0);
    XCTAssertLessThan(s.ms, 1000);
    NSLog(@"launch state: %@", s.raw);
}

- (void)testJumpTo2500 {
    [self tap:@"Jump to 2500"];
    [self settle];
    CFState *s = [self state];
    XCTAssertEqual(s.top, 2500, @"%@", s.raw);
    XCTAssertEqualWithAccuracy(s.y, 0, 2, @"%@", s.raw);
    XCTAssertFalse(s.pinned);
    XCTAssertLessThanOrEqual(s.first, 2500);
    XCTAssertGreaterThanOrEqual(s.last, 2500);
    NSLog(@"jump state: %@", s.raw);
}

- (void)testLoadOlderKeepsPosition {
    [self tap:@"Jump to 2500"];
    [self settle];
    CFState *before = [self state];
    [self tap:@"Load older"];
    [self settle];
    CFState *after = [self state];
    XCTAssertEqual(after.loaded, before.loaded + 40, @"%@", after.raw);
    XCTAssertEqual(after.first, before.first - 40);
    XCTAssertEqual(after.top, before.top, @"%@ -> %@", before.raw, after.raw);
    XCTAssertEqualWithAccuracy(after.y, before.y, 2, @"%@ -> %@", before.raw, after.raw);
}

- (void)testLoadOlderAtBottomStaysPinned {
    [self tap:@"Load older"];
    [self settle];
    CFState *s = [self state];
    XCTAssertEqual(s.loaded, 80);
    XCTAssertTrue(s.pinned, @"%@", s.raw);
}

- (void)testScrollingToTopLoadsOlder {
    XCUIElement *room = self.app.collectionViews[@"room"];
    for (int i = 0; i < 12 && [self state].loaded == 40; i++) {
        [room swipeDown];
    }
    [self settle];
    CFState *s = [self state];
    XCTAssertGreaterThanOrEqual(s.loaded, 80, @"%@", s.raw);
    // Let any fling finish, then check the row on top stays put while nothing changes.
    [NSThread sleepForTimeInterval:2];
    CFState *a = [self state];
    [NSThread sleepForTimeInterval:0.5];
    CFState *b = [self state];
    XCTAssertEqual(a.top, b.top);
    XCTAssertEqualWithAccuracy(a.y, b.y, 2);
}

- (void)testTextSizeKeepsTopRow {
    [self tap:@"Jump to 2500"];
    [self settle];
    for (int i = 0; i < 9; i++) {
        CFState *before = [self state];
        [self tap:@"Text size +"];
        [self settle];
        CFState *after = [self state];
        XCTAssertEqual(after.top, before.top, @"step %d: %@ -> %@", i, before.raw, after.raw);
        XCTAssertEqualWithAccuracy(after.y, before.y, 2, @"step %d: %@ -> %@", i, before.raw, after.raw);
    }
}

- (void)testTextSizeKeepsPinned {
    for (int i = 0; i < 9; i++) {
        [self tap:@"Text size +"];
        [self settle];
        CFState *s = [self state];
        XCTAssertTrue(s.pinned, @"step %d: %@", i, s.raw);
        XCTAssertEqual(s.last, 50000);
    }
}

- (void)testRotationKeepsTopRow {
    [self tap:@"Jump to 2500"];
    [self settle];
    CFState *before = [self state];
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    [NSThread sleepForTimeInterval:1.5];
    CFState *mid = [self state];
    XCTAssertEqual(mid.top, before.top, @"%@ -> %@", before.raw, mid.raw);
    XCTAssertEqualWithAccuracy(mid.y, before.y, 2, @"%@ -> %@", before.raw, mid.raw);
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    [NSThread sleepForTimeInterval:1.5];
    CFState *after = [self state];
    XCTAssertEqual(after.top, before.top, @"%@ -> %@", before.raw, after.raw);
    XCTAssertEqualWithAccuracy(after.y, before.y, 2, @"%@ -> %@", before.raw, after.raw);
}

- (void)testRotationKeepsPinned {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    [NSThread sleepForTimeInterval:1.5];
    XCTAssertTrue([self state].pinned, @"%@", [self state].raw);
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    [NSThread sleepForTimeInterval:1.5];
    XCTAssertTrue([self state].pinned, @"%@", [self state].raw);
}

- (void)testStreamStaysPinned {
    [self tap:@"Start stream"];
    [NSThread sleepForTimeInterval:3];
    CFState *s = [self state];
    XCTAssertTrue(s.pinned, @"%@", s.raw);
    XCTAssertGreaterThan(s.last, 50020, @"%@", s.raw);
    XCTAssertEqual(s.last - s.first + 1, s.loaded);
}

- (void)testStreamWhenScrolledAwayStaysPut {
    XCUIElement *room = self.app.collectionViews[@"room"];
    [room swipeDown];
    [NSThread sleepForTimeInterval:2];
    CFState *before = [self state];
    XCTAssertFalse(before.pinned, @"%@", before.raw);
    [self tap:@"Start stream"];
    [NSThread sleepForTimeInterval:3];
    CFState *after = [self state];
    XCTAssertEqual(after.top, before.top, @"%@ -> %@", before.raw, after.raw);
    XCTAssertEqualWithAccuracy(after.y, before.y, 2, @"%@ -> %@", before.raw, after.raw);
    XCTAssertTrue(self.app.buttons[@"Jump to bottom"].exists);
}

- (void)testStreamDone {
    [self tap:@"Start stream"];
    XCTAssertTrue([self.app.staticTexts[@"Stream done"] waitForExistenceWithTimeout:40]);
    CFState *s = [self state];
    XCTAssertTrue(s.pinned, @"%@", s.raw);
    XCTAssertEqual(s.last, 50600, @"%@", s.raw);
}

- (void)testBoostBurstStaysPinned {
    [self tap:@"Boost burst"];
    [NSThread sleepForTimeInterval:1.6];
    CFState *s = [self state];
    XCTAssertTrue(s.pinned, @"%@", s.raw);
}

- (void)testBoostBurstWhenScrolledAwayStaysPut {
    XCUIElement *room = self.app.collectionViews[@"room"];
    [room swipeDown];
    [NSThread sleepForTimeInterval:2];
    CFState *before = [self state];
    [self tap:@"Boost burst"];
    [NSThread sleepForTimeInterval:1.6];
    CFState *after = [self state];
    XCTAssertEqual(after.top, before.top);
    XCTAssertEqualWithAccuracy(after.y, before.y, 2, @"%@ -> %@", before.raw, after.raw);
}

- (void)testResetReturnsToBottom {
    [self tap:@"Jump to 2500"];
    [self settle];
    [self tap:@"Text size +"];
    [self settle];
    [self tap:@"Reset"];
    [self settle];
    CFState *s = [self state];
    XCTAssertEqual(s.first, 49961);
    XCTAssertEqual(s.last, 50000);
    XCTAssertEqual(s.loaded, 40);
    XCTAssertTrue(s.pinned);
}

- (void)testLongPressShowsCopyAndReply {
    XCUIElement *text = [self.app.textViews elementBoundByIndex:self.app.textViews.count - 1];
    [text pressForDuration:1.2];
    XCTAssertTrue([self.app.menuItems[@"Copy"] waitForExistenceWithTimeout:3]);
    XCTAssertTrue(self.app.menuItems[@"Reply"].exists);
    [self.app.menuItems[@"Copy"] tap];
}

@end

