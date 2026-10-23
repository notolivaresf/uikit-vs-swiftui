#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

// Attribute keys understood by CFTextLayout when drawing.
extern NSAttributedStringKey const CFColorAttributeName;          // NSColor (dynamic colours welcome)
extern NSAttributedStringKey const CFMentionAvatarAttributeName;  // NSNumber user id; run is a placeholder
extern NSAttributedStringKey const CFMentionNameAttributeName;    // NSString, name drawn in the avatar

// Prepared text plus its shaped typesetter. Shaping is the expensive part of layout, so sources are cached
// per message and text size and re-broken into lines when only the width changes.
@interface CFTextSource : NSObject
- (instancetype)initWithString:(NSAttributedString *)string;
@property (nonatomic, readonly) NSAttributedString *attributedString;
@end

// A paragraph of text laid out the way CSS does it: every line is exactly `lineHeight` tall and the glyphs sit
// in the middle of it (half-leading above and below the strut font's ascent + descent).
@interface CFTextLayout : NSObject

+ (instancetype)layoutWithString:(NSAttributedString *)string
                           width:(CGFloat)width
                      lineHeight:(CGFloat)lineHeight
                      strutFont:(NSFont *)font;

// Same, with an explicit baseline adjustment (points, negative = up) instead of the default -1/16 em.
+ (instancetype)layoutWithString:(NSAttributedString *)string
                           width:(CGFloat)width
                      lineHeight:(CGFloat)lineHeight
                       strutFont:(NSFont *)font
                  baselineAdjust:(CGFloat)adjust;

+ (instancetype)layoutWithSource:(CFTextSource *)source
                           width:(CGFloat)width
                      lineHeight:(CGFloat)lineHeight
                       strutFont:(NSFont *)font
                  baselineAdjust:(CGFloat)adjust;

@property (nonatomic, readonly) NSAttributedString *attributedString;
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSSize size;          // width: widest line without trailing spaces
@property (nonatomic, readonly) CGFloat lineHeight;
@property (nonatomic, readonly) NSUInteger lineCount;
// YES when at least one line was broken to fit the width (CSS fit-content then takes the full width).
@property (nonatomic, readonly) BOOL wrapped;

// Draws with the top-left corner at `origin` in a flipped context.
- (void)drawAtPoint:(NSPoint)origin;

// Insertion index nearest to a point given relative to the layout's top-left corner.
- (NSUInteger)characterIndexForPoint:(NSPoint)point;

// Rectangles (relative to the layout's top-left corner) covering a character range, one per line.
- (void)enumerateRectsForRange:(NSRange)range usingBlock:(void (^)(NSRect rect))block;

@end

// Size of a single line of attributed text, used for headers and pills.
NSSize CFSingleLineSize(NSAttributedString *string);

NS_ASSUME_NONNULL_END
