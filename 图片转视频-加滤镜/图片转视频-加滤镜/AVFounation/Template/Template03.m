//
//  Template03.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/8.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "Template03.h"

@implementation Template03
-(instancetype)init{
    if (self = [super init]) {
//       [_filters ]
        [self.filters addObject:[[AnimalFilter alloc] init]];

    }
    return self;
}

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer withTime:(CMTime)currTime{

    float currentTime = CMTimeGetSeconds(currTime);

    CustonFilter *filter = self.filters[0];


    filter.pixelBuffer = pixelBuffer;
    filter.currTime = currTime;
    filter.pixelBuffer = pixelBuffer;
    CVPixelBufferRef outputPixelBuffer = filter.outputPixelBuffer;
    CVPixelBufferRetain(outputPixelBuffer);
    return outputPixelBuffer;
}
@end
