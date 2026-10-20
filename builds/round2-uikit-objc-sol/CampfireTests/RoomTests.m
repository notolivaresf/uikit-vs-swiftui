@import XCTest;
@import UIKit;
@interface RoomTests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end
@implementation RoomTests
- (void)setUp {
    [super setUp]; self.continueAfterFailure=NO;
    XCUIDevice.sharedDevice.orientation=UIDeviceOrientationPortrait;
    self.app=[XCUIApplication new]; self.app.launchArguments=@[@"-uvsBenchmark",@"YES"]; [self.app launch];
    XCTAssertTrue([self.app.staticTexts[@"benchmarkState"] waitForExistenceWithTimeout:5]);
    [self waitFor:@"loaded 40" timeout:5];
}
- (NSString *)state { return self.app.staticTexts[@"benchmarkState"].label; }
- (double)value:(NSString *)field {
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(?:^| )%@ (-?[0-9.]+)",field] options:0 error:nil];
    NSString *state=[self state]; NSTextCheckingResult *match=[regex firstMatchInString:state options:0 range:NSMakeRange(0,state.length)];
    XCTAssertNotNil(match); return [[state substringWithRange:[match rangeAtIndex:1]] doubleValue];
}
- (void)waitFor:(NSString *)text timeout:(NSTimeInterval)timeout {
    NSPredicate *predicate=[NSPredicate predicateWithFormat:@"label CONTAINS %@",text];
    XCTNSPredicateExpectation *expectation=[[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:self.app.staticTexts[@"benchmarkState"]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:timeout],XCTWaiterResultCompleted,@"Current state: %@",[self state]);
}
- (void)attach:(NSString *)name {
    XCTAttachment *attachment=[XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot]; attachment.name=name; attachment.lifetime=XCTAttachmentLifetimeKeepAlways; [self addAttachment:attachment];
}
- (void)rotate:(UIDeviceOrientation)orientation {
    XCUIDevice.sharedDevice.orientation=orientation;
    BOOL landscape=UIDeviceOrientationIsLandscape(orientation);
    NSPredicate *settled=[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        CGRect frame=self.app.collectionViews[@"messages"].frame;
        return landscape ? frame.size.width>frame.size.height : frame.size.height>frame.size.width;
    }];
    XCTNSPredicateExpectation *layout=[[XCTNSPredicateExpectation alloc] initWithPredicate:settled object:self.app];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[layout] timeout:5],XCTWaiterResultCompleted);
    XCTestExpectation *composited=[[XCTestExpectation alloc] initWithDescription:@"Rotation committed"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ [composited fulfill]; });
    XCTAssertEqual([XCTWaiter waitForExpectations:@[composited] timeout:2],XCTWaiterResultCompleted);
}
- (void)testPagingJumpTextAndRotation {
    XCTAssertEqual([self value:@"first"],49961); XCTAssertEqual([self value:@"last"],50000);
    XCTAssertLessThan([self value:@"ms"],1000); [self waitFor:@"pinned yes" timeout:3];
    [self.app.buttons[@"Jump to 2500"] tap]; [self waitFor:@"top 2500 y 0.0" timeout:3];
    double top=[self value:@"top"], y=[self value:@"y"];
    [self.app.buttons[@"Load older"] tap]; [self waitFor:@"loaded 121" timeout:3];
    XCTAssertEqual([self value:@"top"],top); XCTAssertEqualWithAccuracy([self value:@"y"],y,2);
    [self.app.buttons[@"Text size +"] tap];
    XCTAssertEqual([self value:@"top"],top); XCTAssertEqualWithAccuracy([self value:@"y"],y,2);
    [self attach:@"larger-text-anchored"];
    for(NSInteger step=0;step<8;step++) {
        [self.app.buttons[@"Text size +"] tap];
        XCTAssertEqual([self value:@"top"],top); XCTAssertEqualWithAccuracy([self value:@"y"],y,2);
    }
    [self rotate:UIDeviceOrientationLandscapeLeft];
    [self waitFor:@"top 2500" timeout:4];
    XCTAssertEqualWithAccuracy([self value:@"y"],y,2);
    XCUIElement *mine=self.app.cells[@"row-2500"].textViews.firstMatch;
    XCTAssertTrue(mine.exists);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(mine.frame),CGRectGetMaxX(self.app.collectionViews[@"messages"].frame)-55.92,2);
    XCUIElement *next=self.app.cells[@"row-2501"].textViews.firstMatch;
    NSString *nextText=next.value;
    CGFloat naturalWidth=[nextText sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16]}].width;
    XCTAssertEqualWithAccuracy(next.frame.size.width,naturalWidth,2);
    [self attach:@"landscape-anchored"];
    [self rotate:UIDeviceOrientationPortrait];
    [self.app.buttons[@"Reset"] tap]; [self waitFor:@"loaded 40 pinned yes" timeout:3];
    [self.app.buttons[@"Boost burst"] tap];
    NSPredicate *newBoosts=[NSPredicate predicateWithFormat:@"exists == YES"];
    XCTNSPredicateExpectation *boost=[[XCTNSPredicateExpectation alloc] initWithPredicate:newBoosts object:[self.app.otherElements matchingPredicate:[NSPredicate predicateWithFormat:@"label CONTAINS 'boosted 😂'"]].firstMatch];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[boost] timeout:5],XCTWaiterResultCompleted);
    [self waitFor:@"pinned yes" timeout:3]; [self attach:@"boost-burst-bottom"];
}
- (void)testLiveStreamAndUnpinnedAnchor {
    [self.app.buttons[@"Jump to 2500"] tap]; [self waitFor:@"top 2500 y 0.0" timeout:3];
    [self.app.buttons[@"Start stream"] tap];
    NSPredicate *done=[NSPredicate predicateWithFormat:@"label == 'Stream done'"];
    XCTNSPredicateExpectation *end=[[XCTNSPredicateExpectation alloc] initWithPredicate:done object:self.app.staticTexts[@"streamState"]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[end] timeout:35],XCTWaiterResultCompleted);
    XCTAssertEqual([self value:@"last"],50600); XCTAssertEqual([self value:@"top"],2500); XCTAssertEqualWithAccuracy([self value:@"y"],0,2);
    XCTAssertTrue(self.app.buttons[@"↓  Jump to bottom"].exists); [self attach:@"stream-kept-position"];
    [self.app.buttons[@"↓  Jump to bottom"] tap]; [self waitFor:@"pinned yes" timeout:3]; [self attach:@"stream-bottom"];
}
- (void)testPinnedStreamAndBoostAnchor {
    [self.app.buttons[@"Start stream"] tap];
    NSPredicate *done=[NSPredicate predicateWithFormat:@"label == 'Stream done'"];
    XCTNSPredicateExpectation *end=[[XCTNSPredicateExpectation alloc] initWithPredicate:done object:self.app.staticTexts[@"streamState"]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[end] timeout:35],XCTWaiterResultCompleted);
    XCTAssertEqual([self value:@"last"],50600); [self waitFor:@"pinned yes" timeout:3];
    [self.app.buttons[@"Text size +"] tap]; [self waitFor:@"pinned yes" timeout:3];
    [self rotate:UIDeviceOrientationLandscapeLeft];
    [self waitFor:@"pinned yes" timeout:3]; [self attach:@"pinned-landscape"];
    [self rotate:UIDeviceOrientationPortrait];
    [self.app.buttons[@"Jump to 2500"] tap]; [self waitFor:@"top 2500 y 0.0" timeout:3];
    [self.app.buttons[@"Boost burst"] tap];
    [self waitFor:@"top 2500 y 0.0" timeout:3];
}
- (void)testScrollLoadsOlderAndSelection {
    XCUIElement *collection=self.app.collectionViews[@"messages"];
    for(NSInteger i=0;i<15 && [self value:@"loaded"]==40;i++) [collection swipeDownWithVelocity:3000];
    XCTAssertGreaterThan([self value:@"loaded"],40);
    [self attach:@"older-page"];
    XCUIElement *text=nil;
    for(XCUIElement *candidate in self.app.textViews.allElementsBoundByIndex) {
        CGPoint center=CGPointMake(CGRectGetMidX(candidate.frame),CGRectGetMidY(candidate.frame));
        if(candidate.hittable && CGRectContainsPoint(collection.frame,center) && candidate.frame.origin.y>collection.frame.origin.y+4 && [candidate.value length]>40) { text=candidate; break; }
    }
    XCTAssertTrue(text.exists);
    XCUICoordinate *word=[[text coordinateWithNormalizedOffset:CGVectorMake(0,0)] coordinateWithOffset:CGVectorMake(10,10)];
    [word pressForDuration:1.2];
    [self attach:@"selected-range"];
    XCTAssertTrue([self.app.menuItems[@"Copy"] waitForExistenceWithTimeout:3] || self.app.buttons[@"Copy"].exists);
    XCTAssertTrue(self.app.menuItems[@"Reply"].exists || self.app.buttons[@"Reply"].exists);
    [self attach:@"text-selection-menu"];
}
@end
