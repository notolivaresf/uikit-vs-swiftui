#import <AppKit/AppKit.h>
#import "CFRowLayout.h"

NS_ASSUME_NONNULL_BEGIN

// The scroll view's document view: lays rows out top to bottom, keeps views only for rows near the visible area,
// and owns text selection across rows (drag, double-click, Command-C) and the row context menu.
@interface CFRoomView : NSView

@property (nonatomic, readonly) NSArray<CFRowLayout *> *rows;
@property (nonatomic, readonly) CGFloat contentHeight;
@property (nonatomic, readonly) BOOL showsWelcome;

// Replaces all rows. `welcome` shows the room's welcome card above the first row. Sets the view's height.
- (void)setRows:(NSArray<CFRowLayout *> *)rows welcome:(BOOL)welcome;

// Text currently selected (empty when none).
@property (nonatomic, readonly) NSString *selectedText;

- (CGFloat)topOfRowAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfMessageID:(NSInteger)messageID;
// Index of the first row whose bottom is below `y` (NSNotFound when there are no rows).
- (NSUInteger)indexOfRowAtOrBelowY:(CGFloat)y;

// Creates / drops row views for the current visible rect.
- (void)tile;
- (void)clearSelection;
- (void)copy:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
