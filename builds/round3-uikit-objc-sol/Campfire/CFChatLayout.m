#import "CFChatLayout.h"
#import "CFMessageView.h"

@interface CFHeightNode : NSObject
@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong, nullable) CFRow *row;
@property (nonatomic, strong, nullable) CFHeightNode *left;
@property (nonatomic, strong, nullable) CFHeightNode *right;
@property (nonatomic, weak, nullable) CFHeightNode *parent;
@property (nonatomic) NSUInteger count;
@property (nonatomic) uint64_t priority;
@property (nonatomic) CGFloat span;
@property (nonatomic) CGFloat total;
@end
@implementation CFHeightNode
@end

static CGFloat CFRowGap(CFHeightNode *node) {
    return node.row && !node.row.presentation.isThreaded ? 21.28 : 0;
}
static void CFUpdateNode(CFHeightNode *node) {
    node.count=1+node.left.count+node.right.count;
    node.span=node.row ? MAX(1,node.row.height)+CFRowGap(node) : 380;
    node.total=node.left.total+node.span+node.right.total;
}
static CFHeightNode *CFJoinNodes(CFHeightNode *left, CFHeightNode *right) {
    if(!left) { right.parent=nil; return right; }
    if(!right) { left.parent=nil; return left; }
    if(left.priority<right.priority) {
        left.right=CFJoinNodes(left.right,right); left.right.parent=left;
        CFUpdateNode(left); left.parent=nil; return left;
    }
    right.left=CFJoinNodes(left,right.left); right.left.parent=right;
    CFUpdateNode(right); right.parent=nil; return right;
}
static void CFRefreshTree(CFHeightNode *node) {
    if(!node) return;
    CFRefreshTree(node.left); CFRefreshTree(node.right); CFUpdateNode(node);
}
static UICollectionViewLayoutAttributes *CFAttributesForNode(CFHeightNode *node, NSUInteger index, CGFloat y, CGFloat width) {
    UICollectionViewLayoutAttributes *attributes=[UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
    CGFloat gap=CFRowGap(node);
    attributes.frame=CGRectMake(0,y+gap,width,node.span-gap);
    return attributes;
}
static void CFCollectAttributes(CFHeightNode *node, NSUInteger index, CGFloat y, CGFloat width, CGRect rect, NSMutableArray<UICollectionViewLayoutAttributes *> *result) {
    if(!node || y+node.total<CGRectGetMinY(rect) || y>CGRectGetMaxY(rect)) return;
    CFCollectAttributes(node.left,index,y,width,rect,result);
    NSUInteger ownIndex=index+node.left.count;
    CGFloat ownY=y+node.left.total;
    if(ownY+node.span>CGRectGetMinY(rect) && ownY+CFRowGap(node)<CGRectGetMaxY(rect))
        [result addObject:CFAttributesForNode(node,ownIndex,ownY,width)];
    CFCollectAttributes(node.right,ownIndex+1,ownY+node.span,width,rect,result);
}

@interface CFChatLayout ()
@property (nonatomic, strong, nullable) CFHeightNode *root;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,CFHeightNode *> *nodes;
@end
@implementation CFChatLayout
- (instancetype)init {
    if((self=[super init])) _nodes=[NSMutableDictionary new];
    return self;
}
- (NSUInteger)count { return self.root.count; }
- (void)removeAllRows { self.root=nil; [self.nodes removeAllObjects]; }
- (CFHeightNode *)nodeForRow:(CFRow *)row {
    CFHeightNode *node=[CFHeightNode new]; node.row=row;
    node.identifier=row ? @(row.message.messageID) : @0;
    // SplitMix64 distributes monotonic message IDs, keeping the index balanced
    // without shared random state or dependence on the message text.
    uint64_t value=node.identifier.unsignedLongLongValue+UINT64_C(0x9e3779b97f4a7c15);
    value=(value^(value>>30))*UINT64_C(0xbf58476d1ce4e5b9);
    value=(value^(value>>27))*UINT64_C(0x94d049bb133111eb);
    node.priority=value^(value>>31); CFUpdateNode(node);
    self.nodes[node.identifier]=node;
    return node;
}
- (void)appendRows:(NSArray<CFRow *> *)rows {
    for(CFRow *row in rows) self.root=CFJoinNodes(self.root,[self nodeForRow:row]);
}
- (void)prependRows:(NSArray<CFRow *> *)rows {
    CFHeightNode *prefix=nil;
    if(rows.firstObject.message.messageID==1 && !self.nodes[@0]) prefix=[self nodeForRow:nil];
    for(CFRow *row in rows) prefix=CFJoinNodes(prefix,[self nodeForRow:row]);
    self.root=CFJoinNodes(prefix,self.root);
}
- (void)updateRow:(CFRow *)row {
    CFHeightNode *node=self.nodes[@(row.message.messageID)];
    while(node) { CFUpdateNode(node); node=node.parent; }
}
- (void)refreshHeights { CFRefreshTree(self.root); }
- (nullable CFHeightNode *)nodeAtIndex:(NSUInteger)index offset:(CGFloat *)offset {
    CFHeightNode *node=self.root; CGFloat y=0;
    while(node) {
        NSUInteger left=node.left.count;
        if(index<left) node=node.left;
        else if(index==left) { if(offset) *offset=y+node.left.total; return node; }
        else { index-=left+1; y+=node.left.total+node.span; node=node.right; }
    }
    return nil;
}
- (nullable NSNumber *)identifierAtIndexPath:(NSIndexPath *)path {
    return path.section==0 ? [self nodeAtIndex:path.item offset:NULL].identifier : nil;
}
- (nullable NSIndexPath *)indexPathForIdentifier:(NSNumber *)identifier {
    CFHeightNode *node=self.nodes[identifier]; if(!node) return nil;
    NSUInteger index=node.left.count;
    while(node.parent) {
        CFHeightNode *parent=node.parent;
        if(parent.right==node) index+=parent.left.count+1;
        node=parent;
    }
    return [NSIndexPath indexPathForItem:index inSection:0];
}
- (CGSize)collectionViewContentSize { return CGSizeMake(self.collectionView.bounds.size.width,self.root.total); }
- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray *result=[NSMutableArray new];
    CFCollectAttributes(self.root,0,0,self.collectionView.bounds.size.width,rect,result);
    return result;
}
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path {
    if(path.section!=0) return nil;
    CGFloat y=0; CFHeightNode *node=[self nodeAtIndex:path.item offset:&y];
    return node ? CFAttributesForNode(node,path.item,y,self.collectionView.bounds.size.width) : nil;
}
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return fabs(newBounds.size.width-self.collectionView.bounds.size.width)>.1;
}
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposed {
    NSDictionary *anchor=self.anchor;
    if(!anchor) return proposed;
    CGFloat maximum=MAX(0,self.root.total-self.collectionView.bounds.size.height);
    CGFloat y=proposed.y;
    if([anchor[@"pinned"] boolValue]) y=maximum;
    else if(anchor[@"id"]) {
        NSIndexPath *path=[self indexPathForIdentifier:anchor[@"id"]];
        if(path) y=[self layoutAttributesForItemAtIndexPath:path].frame.origin.y-[anchor[@"y"] doubleValue];
    } else if(anchor[@"offset"]) y=[anchor[@"offset"] doubleValue];
    return CGPointMake(0,MAX(0,MIN(y,maximum)));
}
@end
