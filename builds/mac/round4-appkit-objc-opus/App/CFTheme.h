#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

// Geometry measured from ONCE Campfire at 393 x 852 pt (Fixtures/constants.json and the screenshots).
// All values are points. Text-dependent values are multiplied by the current text scale.

extern const CGFloat CFScreenPadX;          // 14.01: avatar inset from the window edge
extern const CGFloat CFAvatarSize;          // 35.27
extern const CGFloat CFAvatarRing;          // background-coloured ring drawn around the avatar
extern const CGFloat CFBubbleInset;         // 40.8: bubble x for others, right inset for mine
extern const CGFloat CFBubbleFarInset;      // 14.0: inset of the far side of the bubble
extern const CGFloat CFBubbleRadius;        // 10.56
extern const CGFloat CFBubblePadY;          // 10.56
extern const CGFloat CFBubblePadX;          // 15.12
extern const CGFloat CFBubbleTopMargin;     // 1.59
extern const CGFloat CFBubbleBottomMargin;  // 1.6
extern const CGFloat CFRowGap;              // 21.28
extern const CGFloat CFThreadedMarginTop;   // -22.48
extern const CGFloat CFHeaderHeight;        // 57.6: the room header (General, buttons)
extern const CGFloat CFComposerHeight;      // 90: composer area under the room
extern const CGFloat CFImageMaxWidth;       // 300

// Text scale steps for the app's own text size (default first).
extern const NSInteger CFTextScaleCount;
CGFloat CFTextScaleAt(NSInteger step);

@interface CFTheme : NSObject

// Colours resolve against the drawing appearance (light / dark follow the system).
@property (class, readonly) NSColor *background;
@property (class, readonly) NSColor *text;
@property (class, readonly) NSColor *bubble;
@property (class, readonly) NSColor *border;
@property (class, readonly) NSColor *borderDark;
@property (class, readonly) NSColor *borderDarker;
@property (class, readonly) NSColor *mentionBubble;
@property (class, readonly) NSColor *pillBackground;
@property (class, readonly) NSColor *codeBackground;
@property (class, readonly) NSColor *codeKeyword;
@property (class, readonly) NSColor *codeEntity;
@property (class, readonly) NSColor *codeConstant;
@property (class, readonly) NSColor *codeString;
@property (class, readonly) NSColor *codeComment;
@property (class, readonly) NSColor *link;
@property (class, readonly) NSColor *selection;
@property (class, readonly) NSColor *orange;
@property (class, readonly) NSColor *dimText;   // text at 50 %

+ (NSColor *)avatarColorForUserID:(NSInteger)userID;
+ (BOOL)isDark:(NSAppearance *)appearance;

+ (NSFont *)fontOfSize:(CGFloat)size weight:(NSFontWeight)weight;
+ (NSFont *)monoFontOfSize:(CGFloat)size;
+ (CGFloat)monoKernForFont:(NSFont *)font;

@end

// Draws a filled circle with a white bold initial (avatars, boost avatars, mention avatars).
void CFDrawAvatar(NSRect rect, NSString *name, NSInteger userID, CGFloat fontSize);

NS_ASSUME_NONNULL_END
