#import "CFRoomView.h"
#import "CFChromeViews.h"
#import "CFTheme.h"

typedef struct {
    NSInteger messageID;
    NSInteger fragment;
    NSUInteger offset;
} CFTextPosition;

// Draws one row. Never takes mouse events: the room view handles them so selection can span rows.
@interface CFRowView : NSView
@property (nonatomic, strong) CFRowLayout *layout;
@property (nonatomic, copy) NSArray<NSValue *> *selection;
@end

@implementation CFRowView

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.wantsLayer = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)drawRect:(NSRect)dirtyRect {
    [self.layout drawWithSelection:self.selection];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

@end

@interface CFRoomView () <NSMenuItemValidation>
@end

@implementation CFRoomView {
    NSArray<CFRowLayout *> *_rows;
    NSMutableData *_tops;
    NSMutableData *_bottoms;   // row bottoms, clipped to the next row's top (threaded rows overlap by 1.2 pt)
    NSMutableDictionary<NSNumber *, CFRowView *> *_views;
    NSMutableDictionary<NSNumber *, NSNumber *> *_indexByID;
    CFWelcomeView *_welcome;
    BOOL _hasSelection;
    BOOL _dragging;
    CFTextPosition _anchor, _focus;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _rows = @[];
        _tops = [NSMutableData data];
        _bottoms = [NSMutableData data];
        _views = [NSMutableDictionary dictionary];
        _indexByID = [NSMutableDictionary dictionary];
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

#pragma mark - Rows

- (NSArray<CFRowLayout *> *)rows { return _rows; }

- (void)setRows:(NSArray<CFRowLayout *> *)rows welcome:(BOOL)welcome {
    _rows = [rows copy];
    _showsWelcome = welcome;
    [_indexByID removeAllObjects];
    _tops.length = rows.count * sizeof(CGFloat);
    CGFloat *tops = _tops.mutableBytes;
    CGFloat y = welcome ? CFWelcomeHeight : CFRowGap;
    CGFloat bottom = y;
    for (NSUInteger i = 0; i < rows.count; i++) {
        CFRowLayout *r = rows[i];
        if (i > 0) y = bottom + r.marginTop;
        tops[i] = y;
        bottom = y + r.height;
        _indexByID[@(r.message.messageID)] = @(i);
    }
    _contentHeight = bottom;
    _bottoms.length = rows.count * sizeof(CGFloat);
    CGFloat *bottoms = _bottoms.mutableBytes;
    for (NSUInteger i = 0; i < rows.count; i++) {
        CGFloat b = tops[i] + rows[i].height;
        bottoms[i] = i + 1 < rows.count ? MIN(b, tops[i + 1]) : b;
    }

    if (welcome && !_welcome) {
        _welcome = [[CFWelcomeView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_welcome positioned:NSWindowBelow relativeTo:nil];
    } else if (!welcome && _welcome) {
        [_welcome removeFromSuperview];
        _welcome = nil;
    }
    _welcome.frame = NSMakeRect(0, 0, self.frame.size.width, CFWelcomeHeight);

    if (_hasSelection && ([self indexOfMessageID:_anchor.messageID] == NSNotFound ||
                          [self indexOfMessageID:_focus.messageID] == NSNotFound)) {
        _hasSelection = NO;
    }
    [self setFrameSize:NSMakeSize(self.frame.size.width, ceil(_contentHeight))];
    [self tile];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    _welcome.frame = NSMakeRect(0, 0, newSize.width, CFWelcomeHeight);
}

- (CGFloat)topOfRowAtIndex:(NSUInteger)index {
    if (index >= _rows.count) return _contentHeight;
    return ((const CGFloat *)_tops.bytes)[index];
}

- (NSUInteger)indexOfMessageID:(NSInteger)messageID {
    NSNumber *n = _indexByID[@(messageID)];
    return n ? n.unsignedIntegerValue : NSNotFound;
}

- (NSUInteger)indexOfRowAtOrBelowY:(CGFloat)y {
    // First row whose bottom edge is below y (binary search over increasing bottoms).
    NSUInteger lo = 0, hi = _rows.count;
    const CGFloat *bottoms = _bottoms.bytes;
    while (lo < hi) {
        NSUInteger mid = (lo + hi) / 2;
        if (bottoms[mid] <= y + 0.001) lo = mid + 1; else hi = mid;
    }
    return lo < _rows.count ? lo : NSNotFound;
}

- (void)tile {
    NSRect visible = self.visibleRect;
    CGFloat over = MAX(visible.size.height, 400);
    CGFloat y0 = NSMinY(visible) - over, y1 = NSMaxY(visible) + over;
    NSMutableSet<NSNumber *> *keep = [NSMutableSet set];
    NSUInteger first = [self indexOfRowAtOrBelowY:y0];
    if (first != NSNotFound) {
        const CGFloat *tops = _tops.bytes;
        CGFloat width = self.frame.size.width;
        for (NSUInteger i = first; i < _rows.count && tops[i] < y1; i++) {
            CFRowLayout *layout = _rows[i];
            NSNumber *key = @(layout.message.messageID);
            [keep addObject:key];
            CFRowView *v = _views[key];
            NSRect frame = NSMakeRect(0, tops[i], width, layout.height);
            if (!v) {
                v = [[CFRowView alloc] initWithFrame:frame];
                _views[key] = v;
                [self addSubview:v];
            }
            if (!NSEqualRects(v.frame, frame)) v.frame = frame;
            NSArray *sel = [self selectionForRowAtIndex:i];
            if (v.layout != layout || !((v.selection == nil && sel == nil) || [v.selection isEqualToArray:sel])) {
                v.layout = layout;
                v.selection = sel;
                v.needsDisplay = YES;
            }
        }
    }
    for (NSNumber *key in _views.allKeys) {
        if (![keep containsObject:key]) {
            [_views[key] removeFromSuperview];
            [_views removeObjectForKey:key];
        }
    }
    [self.window invalidateCursorRectsForView:self];
}

- (void)resetCursorRects {
    NSRect visible = self.visibleRect;
    NSUInteger first = [self indexOfRowAtOrBelowY:NSMinY(visible)];
    if (first == NSNotFound) return;
    const CGFloat *tops = _tops.bytes;
    for (NSUInteger i = first; i < _rows.count && tops[i] < NSMaxY(visible); i++) {
        for (CFTextFragment *f in _rows[i].fragments) {
            NSRect r = NSIntersectionRect(NSOffsetRect(f.frame, 0, tops[i]), visible);
            if (!NSIsEmptyRect(r)) [self addCursorRect:r cursor:NSCursor.IBeamCursor];
        }
    }
}

#pragma mark - Selection model

static NSComparisonResult ComparePositions(CFRoomView *v, CFTextPosition a, CFTextPosition b) {
    NSUInteger ia = [v indexOfMessageID:a.messageID], ib = [v indexOfMessageID:b.messageID];
    if (ia != ib) return ia < ib ? NSOrderedAscending : NSOrderedDescending;
    if (a.fragment != b.fragment) return a.fragment < b.fragment ? NSOrderedAscending : NSOrderedDescending;
    if (a.offset != b.offset) return a.offset < b.offset ? NSOrderedAscending : NSOrderedDescending;
    return NSOrderedSame;
}

- (BOOL)orderedSelectionStart:(CFTextPosition *)start end:(CFTextPosition *)end {
    if (!_hasSelection) return NO;
    if (ComparePositions(self, _anchor, _focus) == NSOrderedSame) return NO;
    BOOL forward = ComparePositions(self, _anchor, _focus) == NSOrderedAscending;
    *start = forward ? _anchor : _focus;
    *end = forward ? _focus : _anchor;
    return YES;
}

- (NSArray<NSValue *> *)selectionForRowAtIndex:(NSUInteger)index {
    CFTextPosition s, e;
    if (![self orderedSelectionStart:&s end:&e]) return nil;
    NSUInteger is = [self indexOfMessageID:s.messageID], ie = [self indexOfMessageID:e.messageID];
    if (index < is || index > ie) return nil;
    NSArray<CFTextFragment *> *frags = _rows[index].fragments;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:frags.count];
    for (NSInteger f = 0; f < (NSInteger)frags.count; f++) {
        NSUInteger len = frags[f].layout.string.length;
        NSUInteger a = 0, b = len;
        if (index == is) {
            if (f < s.fragment) { [out addObject:[NSValue valueWithRange:NSMakeRange(NSNotFound, 0)]]; continue; }
            if (f == s.fragment) a = MIN(s.offset, len);
        }
        if (index == ie) {
            if (f > e.fragment) { [out addObject:[NSValue valueWithRange:NSMakeRange(NSNotFound, 0)]]; continue; }
            if (f == e.fragment) b = MIN(e.offset, len);
        }
        [out addObject:[NSValue valueWithRange:b > a ? NSMakeRange(a, b - a) : NSMakeRange(NSNotFound, 0)]];
    }
    return out;
}

- (NSString *)selectedText {
    CFTextPosition s, e;
    if (![self orderedSelectionStart:&s end:&e]) return @"";
    NSUInteger is = [self indexOfMessageID:s.messageID], ie = [self indexOfMessageID:e.messageID];
    NSMutableArray<NSString *> *rowsText = [NSMutableArray array];
    for (NSUInteger i = is; i <= ie && i < _rows.count; i++) {
        NSArray<NSValue *> *sel = [self selectionForRowAtIndex:i];
        NSArray<CFTextFragment *> *frags = _rows[i].fragments;
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (NSUInteger f = 0; f < frags.count && f < sel.count; f++) {
            NSRange r = sel[f].rangeValue;
            if (r.location == NSNotFound || r.length == 0) continue;
            NSString *t = [frags[f].layout.string substringWithRange:r];
            [parts addObject:[t stringByReplacingOccurrencesOfString:@"￼" withString:@""]];
        }
        if (parts.count) [rowsText addObject:[parts componentsJoinedByString:@"\n"]];
    }
    return [rowsText componentsJoinedByString:@"\n"];
}

- (void)clearSelection {
    if (!_hasSelection) return;
    _hasSelection = NO;
    [self tile];
}

// Nearest text position to a point in this view's coordinates.
- (BOOL)position:(CFTextPosition *)pos atPoint:(NSPoint)p {
    if (_rows.count == 0) return NO;
    const CGFloat *tops = _tops.bytes;
    NSUInteger i = [self indexOfRowAtOrBelowY:p.y];
    if (i == NSNotFound) {
        i = _rows.count - 1;
        p.y = tops[i] + _rows[i].height + 1;
    }
    // Skip rows that have no text, moving forward (then backward).
    NSUInteger j = i;
    while (j < _rows.count && _rows[j].fragments.count == 0) j++;
    if (j >= _rows.count) {
        j = i;
        while (j > 0 && _rows[j].fragments.count == 0) j--;
        if (_rows[j].fragments.count == 0) return NO;
        CFTextFragment *last = _rows[j].fragments.lastObject;
        *pos = (CFTextPosition){_rows[j].message.messageID, (NSInteger)_rows[j].fragments.count - 1, last.layout.string.length};
        return YES;
    }
    if (j != i) {
        *pos = (CFTextPosition){_rows[j].message.messageID, 0, 0};
        return YES;
    }
    CFRowLayout *row = _rows[i];
    NSPoint local = NSMakePoint(p.x, p.y - tops[i]);
    NSArray<CFTextFragment *> *frags = row.fragments;
    for (NSUInteger f = 0; f < frags.count; f++) {
        NSRect fr = frags[f].frame;
        if (local.y < NSMinY(fr)) {
            *pos = (CFTextPosition){row.message.messageID, (NSInteger)f, 0};
            return YES;
        }
        if (local.y < NSMaxY(fr) || f == frags.count - 1) {
            NSPoint q = NSMakePoint(local.x - fr.origin.x, local.y - fr.origin.y);
            NSUInteger idx = [frags[f].layout characterIndexForPoint:q];
            *pos = (CFTextPosition){row.message.messageID, (NSInteger)f, idx};
            return YES;
        }
    }
    return NO;
}

#pragma mark - Mouse

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    if (event.modifierFlags & NSEventModifierFlagControl) {
        // Control-click is a right-click: show the message menu, keep the selection.
        NSMenu *menu = [self menuForEvent:event];
        if (menu) [NSMenu popUpContextMenu:menu withEvent:event forView:self];
        return;
    }
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    CFTextPosition pos;
    if (![self position:&pos atPoint:p]) {
        [self clearSelection];
        return;
    }
    _dragging = YES;
    NSUInteger ri = [self indexOfMessageID:pos.messageID];
    CFTextFragment *frag = _rows[ri].fragments[(NSUInteger)pos.fragment];
    NSString *string = frag.layout.string;
    if (event.clickCount == 2 && string.length) {
        NSUInteger at = MIN(pos.offset, string.length - 1);
        NSRange word = [frag.layout.attributedString doubleClickAtIndex:at];
        _anchor = (CFTextPosition){pos.messageID, pos.fragment, word.location};
        _focus = (CFTextPosition){pos.messageID, pos.fragment, NSMaxRange(word)};
    } else if (event.clickCount >= 3 && string.length) {
        NSRange para = [string paragraphRangeForRange:NSMakeRange(MIN(pos.offset, string.length - 1), 0)];
        NSUInteger end = NSMaxRange(para);
        if (end > para.location && [string characterAtIndex:end - 1] == '\n') end--;
        _anchor = (CFTextPosition){pos.messageID, pos.fragment, para.location};
        _focus = (CFTextPosition){pos.messageID, pos.fragment, end};
    } else {
        _anchor = _focus = pos;
    }
    _hasSelection = YES;
    [self tile];
}

- (void)mouseUp:(NSEvent *)event {
    _dragging = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    if (!_hasSelection || !_dragging) return;
    [self autoscroll:event];
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    CFTextPosition pos;
    if ([self position:&pos atPoint:p]) {
        _focus = pos;
        [self tile];
    }
}

- (void)copy:(id)sender {
    NSString *text = self.selectedText;
    if (text.length == 0) return;
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    [pb setString:text forType:NSPasteboardTypeString];
}

- (void)selectAll:(id)sender {
    if (_rows.count == 0) return;
    NSInteger firstText = -1, lastText = -1;
    for (NSUInteger i = 0; i < _rows.count; i++) {
        if (_rows[i].fragments.count) { if (firstText < 0) firstText = (NSInteger)i; lastText = (NSInteger)i; }
    }
    if (firstText < 0) return;
    CFRowLayout *a = _rows[(NSUInteger)firstText], *b = _rows[(NSUInteger)lastText];
    _anchor = (CFTextPosition){a.message.messageID, 0, 0};
    _focus = (CFTextPosition){b.message.messageID, (NSInteger)b.fragments.count - 1, b.fragments.lastObject.layout.string.length};
    _hasSelection = YES;
    [self tile];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(copy:)) return self.selectedText.length > 0;
    if (item.action == @selector(copyMessage:) || item.action == @selector(reply:)) return YES;
    if (item.action == @selector(selectAll:)) return _rows.count > 0;
    return YES;
}

#pragma mark - Context menu

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    NSUInteger i = [self indexOfRowAtOrBelowY:p.y];
    if (i == NSNotFound || p.y < [self topOfRowAtIndex:i]) return nil;
    CFMessage *m = _rows[i].message;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Message"];
    NSMenuItem *copy = [menu addItemWithTitle:@"Copy" action:@selector(copyMessage:) keyEquivalent:@""];
    copy.target = self;
    copy.representedObject = m;
    NSMenuItem *reply = [menu addItemWithTitle:@"Reply" action:@selector(reply:) keyEquivalent:@""];
    reply.target = self;
    reply.representedObject = m;
    return menu;
}

- (void)copyMessage:(NSMenuItem *)sender {
    CFMessage *m = sender.representedObject;
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    [pb setString:m.displayText forType:NSPasteboardTypeString];
}

- (void)reply:(NSMenuItem *)sender {
    // Drawn but does nothing in this UI test.
}

@end
