@import Foundation;
@import CampfireKitObjC;

int main(void) {
    @autoreleasepool {
        CFKDataset *d = [[CFKDataset alloc] init];
        CFKPage *p = [d lastPage];
        NSLog(@"messages %ld, page %lu, users %lu", (long)d.messageCount, (unsigned long)p.messages.count, (unsigned long)d.users.count);
        for (NSUInteger i = 0; i < 3; i++) {
            CFKMessage *m = p.messages[i];
            CFKPresentation *pr = p.presentations[i];
            CFKUser *u = [d userWithID:m.creatorID];
            NSLog(@"#%ld by %@ blocks %lu threaded %d first-of-day %d: %@", (long)m.messageID, u.name, (unsigned long)m.blocks.count, pr.isThreaded, pr.isFirstOfDay, m.plainText);
        }
        CFKBlockKind k = p.messages[0].blocks[0].kind;
        NSLog(@"first block kind %ld (text=%ld)", (long)k, (long)CFKBlockKindText);
        CFKLiveFeed *feed = [[CFKLiveFeed alloc] initWithDataset:d messagesPerSecond:100 duration:0.2];
        __block int n = 0;
        CFKFeedHandle *h = [feed startOnEvent:^(CFKFeedEvent *e) { n++; } completion:^{
            NSLog(@"feed done, %d events, expected %ld", n, (long)feed.eventCount);
            exit(0);
        }];
        (void)h;
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
