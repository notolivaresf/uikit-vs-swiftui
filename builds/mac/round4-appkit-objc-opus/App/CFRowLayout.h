#import <AppKit/AppKit.h>
#import "CFMessage.h"
#import "CFTextLayout.h"

NS_ASSUME_NONNULL_BEGIN

// A selectable run of text inside a row (message text, a code block, a file name).
@interface CFTextFragment : NSObject
@property (nonatomic, strong) CFTextLayout *layout;
@property (nonatomic) NSPoint origin;   // top-left, relative to the row
@property (nonatomic, readonly) NSRect frame;
@end

// Geometry of one message row at a given width and text scale, plus its drawing.
// Coordinates are flipped (y down) and relative to the row's top-left corner.
@interface CFRowLayout : NSObject

+ (instancetype)layoutForMessage:(CFMessage *)message width:(CGFloat)width scale:(CGFloat)scale;

@property (nonatomic, readonly) CFMessage *message;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, readonly) NSRect bubbleRect;
@property (nonatomic, readonly) NSArray<CFTextFragment *> *fragments;

// Space between the previous row's bottom and this row's top (negative for threaded rows).
@property (nonatomic, readonly) CGFloat marginTop;

// `selection` holds one NSRange value per fragment (location NSNotFound = nothing selected there).
- (void)drawWithSelection:(nullable NSArray<NSValue *> *)selection;

@end

// Shared formatting.
NSString *CFTimeString(NSDate *date);
NSString *CFDayString(NSDate *date);

// Draws an SF Symbol tinted with `color`, centred in `rect`.
void CFDrawSymbol(NSString *name, NSRect rect, CGFloat pointSize, NSFontWeight weight, NSColor *color);

NS_ASSUME_NONNULL_END
