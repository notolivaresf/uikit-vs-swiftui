@import Cocoa;
@import CampfireKitObjC;

NSColor *CFColor(NSString *light, NSString *dark);
NSColor *CFBackground(void);
NSColor *CFText(void);
NSColor *CFBubble(void);
NSFont *CFFont(CGFloat size, BOOL bold);
void CFDraw(NSString *text, NSRect rect, CGFloat size, BOOL bold, NSColor *color);
void CFRound(NSRect rect, CGFloat radius, NSColor *fill, NSColor *stroke, CGFloat line);
void CFIcon(NSString *name, NSRect rect, NSColor *color);

@interface CFFlippedView : NSView
@end
@interface CFChrome : CFFlippedView
@property BOOL composer;
@property(copy) NSString *roomName;
@end
@interface CFWelcome : CFFlippedView
@end

@interface CFRowLayout : NSObject
@property CFKMessage *message;
@property CFKPresentation *presentation;
@property CFKUser *user;
@property CGFloat y, height, scale;
@property NSRect bubble, textFrame, codeFrame, attachmentFrame;
@property NSAttributedString *body, *code;
@property NSArray<NSDictionary *> *boosts;
@property NSArray<NSValue *> *boostFrames;
@property NSRect addBoostFrame;
@property NSString *time, *day;
+ (instancetype)layoutMessage:(CFKMessage *)message presentation:(CFKPresentation *)presentation dataset:(CFKDataset *)dataset width:(CGFloat)width scale:(CGFloat)scale extraBoosts:(NSArray *)extras;
@end
@interface CFRowView : CFFlippedView
@property(nonatomic,strong) CFRowLayout *row;
@property CFKDataset *dataset;
@end
@interface CFDocument : CFFlippedView
@end
