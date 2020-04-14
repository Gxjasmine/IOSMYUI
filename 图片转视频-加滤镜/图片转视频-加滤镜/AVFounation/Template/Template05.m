//
//  Template05.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/14.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "Template05.h"

@implementation Template05
-(instancetype)init{
    if (self = [super init]) {
//       [_filters ]
        [self.filters addObject:[[Tem1MixFilter alloc] init]];

    }
    return self;
}

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer withTime:(CMTime)currTime{

    CustonFilter *filter = self.filters[0];

    filter.pixelBuffer = pixelBuffer;
    filter.currTime = currTime;
    filter.pixelBuffer = pixelBuffer;
    CVPixelBufferRef outputPixelBuffer = filter.outputPixelBuffer;
    CVPixelBufferRetain(outputPixelBuffer);
    return outputPixelBuffer;
}
@end
