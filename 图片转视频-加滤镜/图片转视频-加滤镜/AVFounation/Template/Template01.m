//
//  Template01.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "Template01.h"


@implementation Template01
-(instancetype)init{
    if (self = [super init]) {
//       [_filters ]
        [self.filters addObject:[[SouloutFilter alloc] init]];
        [self.filters addObject:[[RotateFilter alloc] init]];
        [self.filters addObject:[[MoveAndRotateFilter alloc] init]];
        [self.filters addObject:[[ScaleFilter alloc] init]];

    }
    return self;
}

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer withTime:(CMTime)currTime{

    float currentTime = CMTimeGetSeconds(currTime);
    NSLog(@"currentTime = %lf",currentTime);

    CustonFilter *filter = nil;
    if (currentTime <= 2.0) {
        filter = self.filters[0];
    }else if (currentTime <= 4.0){
        filter = self.filters[1];

    }else if (currentTime <= 6.0){
        filter = self.filters[2];

    }else {
        filter = self.filters[3];
    }

    filter.pixelBuffer = pixelBuffer;
    filter.currTime = currTime;
    filter.pixelBuffer = pixelBuffer;
    CVPixelBufferRef outputPixelBuffer = filter.outputPixelBuffer;
    CVPixelBufferRetain(outputPixelBuffer);
    return outputPixelBuffer;
}

@end
