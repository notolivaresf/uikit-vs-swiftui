@import UIKit;
@import CampfireKitObjC;
NS_ASSUME_NONNULL_BEGIN
UIColor *CFBackground(void);
UIColor *CFText(void);
UIColor *CFBubble(void);
UIColor *CFBorder(void);
UIColor *CFAvatarColor(NSInteger userID);
UIFont *CFFont(CGFloat size, UIFontWeight weight, CGFloat scale);
UILabel *CFLabel(NSString *text, UIFont *font);
UIButton *CFIconButton(NSString *symbol, NSString *label);
@interface CFRow : NSObject
@property (nonatomic, strong) CFKMessage *message;
@property (nonatomic, strong) CFKPresentation *presentation;
@property (nonatomic, copy) NSArray<NSDictionary *> *extraBoosts;
@property (nonatomic, copy) NSDictionary<NSNumber *, CFKUser *> *users;
@property (nonatomic) CGFloat scale;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat viewportWidth;
@property (nonatomic) CGRect bubbleFrame;
@property (nonatomic) CGRect bodyFrame;
@property (nonatomic) CGRect codeFrame;
@property (nonatomic) CGRect attachmentFrame;
@property (nonatomic) CGFloat headerY;
@property (nonatomic) BOOL headerStacked;
@property (nonatomic) CGFloat contentWidth;
@property (nonatomic, copy) NSAttributedString *body;
@property (nonatomic, copy) NSAttributedString *code;
@property (nonatomic, copy) NSArray<NSDictionary *> *pills;
@property (nonatomic, copy) NSString *time;
@property (nonatomic, copy) NSString *day;
- (void)measureWidth:(CGFloat)width scale:(CGFloat)scale;
@end
@interface CFMessageConfiguration : NSObject <UIContentConfiguration>
@property (nonatomic, strong) CFRow *row;
@end
@interface CFMessageView : UIView <UIContentView>
@property (nonatomic, copy) id<UIContentConfiguration> configuration;
@end
@interface CFWelcomeView : UICollectionViewCell
@end
NS_ASSUME_NONNULL_END
