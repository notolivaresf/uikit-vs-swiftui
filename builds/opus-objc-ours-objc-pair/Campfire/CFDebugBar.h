@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// Benchmark controls, shown when launched with `-uvsBenchmark YES`. Fixed-size text so it never moves with Dynamic Type.
@interface CFDebugBar : UIView
@property (nonatomic, readonly) UIButton *resetButton;
@property (nonatomic, readonly) UIButton *jumpButton;
@property (nonatomic, readonly) UIButton *loadOlderButton;
@property (nonatomic, readonly) UIButton *streamButton;
@property (nonatomic, readonly) UIButton *textSizeButton;
@property (nonatomic, readonly) UIButton *boostBurstButton;
@property (nonatomic, readonly) UILabel *stateLabel;
@property (nonatomic, readonly) UILabel *streamDoneLabel;
+ (CGFloat)heightForWidth:(CGFloat)width;
@end

NS_ASSUME_NONNULL_END
