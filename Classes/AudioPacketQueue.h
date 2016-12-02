//
//  AudioPacketQueue.h
//  iFrameExtractor
//
//  Created by Liao KuoHsun on 13/4/19.
//
//

#ifndef AudioPacketQueue_h
#define AudioPacketQueue_h

#import <Foundation/Foundation.h>
#include "libavformat/avformat.h"

@interface AudioPacketQueue : NSObject{
    NSMutableArray *pQueue;
    NSLock *pLock;

}
@property  (nonatomic)  NSInteger count;
@property  (nonatomic)  NSInteger size;
- (id) initQueue;
- (void) destroyQueue;
-(bool) putAVPacket: (AVPacket *) pkt;
-(bool) getAVPacket :(AVPacket *) pkt;
-(void)freeAVPacket:(AVPacket *) pkt;
@end

#endif
