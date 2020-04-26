//
//  IOpenGLRenderer.h
//  iMyVideoEditor
//
//  Created by fuzhongw on 2020/4/24.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface IOpenGLRenderer : NSObject

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer sourceBuffer:(CVPixelBufferRef)sourceBuffer forTweenFactor:(float)tween;

- (CVPixelBufferRef)renderPixelBufferSourceBuffer:(CVPixelBufferRef)sourceBuffer forTweenFactor:(float)tween;

@end

NS_ASSUME_NONNULL_END
