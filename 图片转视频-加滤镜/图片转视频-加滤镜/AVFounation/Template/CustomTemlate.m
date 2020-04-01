//
//  CustomTemlate.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "CustomTemlate.h"

@implementation CustomTemlate

-(instancetype)init{
    if (self = [super init]) {
        _filters = [NSMutableArray array];
    }
    return self;
}

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer withTime:(CMTime)currTime{
    return nil;
}
@end
