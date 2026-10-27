// The common stopwatch's touch marker (Round 5, 27 Oct). Injected by the harness into the app under test in the
// simulator (DYLD_INSERT_LIBRARIES, only when Harness/stopwatch.sh runs); the app's own code never sees it.
//
// On every touch that ends (the moment a button's action runs), before the app gets the event, it bumps a counter,
// paints the counter's low 8 bits as 8 black or white cells in a strip at the top of the window, and commits that
// at once (CATransaction flush), so the render server shows the new code in the next frame however long the app
// then keeps the main thread busy. The screen recording therefore carries the touch on the same clock as the
// result: Harness/stopwatch.py reads the frame where the code changes (the touch) and the first frame where the
// rest of the screen shows its final picture (the result).
//
// It also appends one line per ended touch to $UVS_STOPWATCH_LOG:
//   <seq> <event timestamp s> <CACurrentMediaTime at dispatch s> <label of the control touched, or ->
// so stopwatch.py knows which code belongs to which button.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#define kCells 8
static const CGFloat kCellW = 12, kCellH = 8, kTop = 2;
static CALayer *gStrip;
static CALayer *gCells[kCells];
static unsigned gSeq;
static FILE *gLog;
static void (*gOrigSendEvent)(id, SEL, UIEvent *);

static NSString *ControlLabel(UIView *v) {
    for (UIView *x = v; x; x = x.superview) {
        if ([x isKindOfClass:[UIControl class]]) {
            NSString *l = x.accessibilityLabel;
            if (!l.length && [x isKindOfClass:[UIButton class]]) l = [(UIButton *)x currentTitle];
            if (!l.length && [x isKindOfClass:[UIButton class]]) l = [(UIButton *)x configuration].title;
            return l.length ? l : @"?";
        }
    }
    return @"-";
}

static void EnsureStrip(UIWindow *w) {
    if (!w) return;
    if (!gStrip) {
        gStrip = [CALayer layer];
        gStrip.zPosition = 1e6;
        gStrip.backgroundColor = UIColor.redColor.CGColor;   // a red frame around the cells: easy to find
        for (int i = 0; i < kCells; i++) {
            gCells[i] = [CALayer layer];
            gCells[i].frame = CGRectMake(2 + i * kCellW, 2, kCellW - 2, kCellH);
            [gStrip addSublayer:gCells[i]];
        }
    }
    if (gStrip.superlayer != w.layer) {
        CGFloat width = 2 + kCells * kCellW;
        gStrip.frame = CGRectMake(floor((w.bounds.size.width - width) / 2), kTop, width, kCellH + 4);
        [w.layer addSublayer:gStrip];
    }
}

static void Paint(unsigned seq) {
    for (int i = 0; i < kCells; i++) {
        BOOL on = (seq >> (kCells - 1 - i)) & 1;
        gCells[i].backgroundColor = on ? UIColor.whiteColor.CGColor : UIColor.blackColor.CGColor;
    }
}

static void UVSSendEvent(id self, SEL _cmd, UIEvent *event) {
    if (event.type == UIEventTypeTouches) {
        UITouch *ended = nil;
        for (UITouch *t in event.allTouches) {
            if (t.phase == UITouchPhaseEnded) { ended = t; break; }
        }
        if (ended) {
            CFTimeInterval now = CACurrentMediaTime();
            gSeq++;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            EnsureStrip(ended.window);
            Paint(gSeq);
            [CATransaction commit];
            [CATransaction flush];
            if (gLog) {
                NSString *label = [ControlLabel(ended.view) stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                fprintf(gLog, "%u %.6f %.6f %s\n", gSeq, event.timestamp, now, label.UTF8String);
                fflush(gLog);
            }
        }
    }
    gOrigSendEvent(self, _cmd, event);
}

__attribute__((constructor)) static void UVSStopwatchInit(void) {
    const char *path = getenv("UVS_STOPWATCH_LOG");
    if (path && *path) gLog = fopen(path, "a");
    if (gLog) { fprintf(gLog, "# start pid %d\n", getpid()); fflush(gLog); }
    Method m = class_getInstanceMethod([UIApplication class], @selector(sendEvent:));
    gOrigSendEvent = (void (*)(id, SEL, UIEvent *))method_setImplementation(m, (IMP)UVSSendEvent);
}
