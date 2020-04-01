//
//  CustomTemlate.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "CustonFilter.h"

#import "ScaleFilter.h"
#import "RotateFilter.h"
#import "MoveAndRotateFilter.h"
#import "MixFilter.h"
#import "SouloutFilter.h"
#import "VertigoFilter.h"
#import "ScaleTwoScreenFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomTemlate : NSObject
@property (copy, nonatomic) NSMutableArray<CustonFilter *> *filters;
/// 处理 pixelBuffer，并返回结果
- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer withTime:(CMTime)currTime;
@end

NS_ASSUME_NONNULL_END
