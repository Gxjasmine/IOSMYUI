//
//  FWCustomVideoCompositor.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FWCustomVideoCompositor : NSObject <AVVideoCompositing>
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *sourcePixelBufferAttributes;
@property (nonatomic, strong) NSDictionary<NSString *, id> *requiredPixelBufferAttributesForRenderContext;
@end

NS_ASSUME_NONNULL_END
