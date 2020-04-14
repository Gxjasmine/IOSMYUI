//
//  CustonFilter.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import "MFPixelBufferHelper.h"
#import "MFShaderHelper.h"

NS_ASSUME_NONNULL_BEGIN
void runSynchronouslyOnVideoProcessingQueue(void (^block)(void));

@interface CustonFilter : NSObject
@property (nonatomic, assign) CVPixelBufferRef resultPixelBuffer;
@property (nonatomic, strong) MFPixelBufferHelper *pixelBufferHelper;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, assign) CMTime currTime;
@property (nonatomic, assign) CVPixelBufferRef backgpixelBuffer;

- (CVPixelBufferRef)outputPixelBuffer;
@end

NS_ASSUME_NONNULL_END
