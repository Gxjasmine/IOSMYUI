//
//  CustonFilter.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "CustonFilter.h"

@import OpenGLES;

@interface CustonFilter ()



@end

@implementation CustonFilter

- (void)dealloc {
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    if (_resultPixelBuffer) {
        CVPixelBufferRelease(_resultPixelBuffer);
    }
}

#pragma mark - Accessors

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (_pixelBuffer &&
        pixelBuffer &&
        CFEqual(pixelBuffer, _pixelBuffer)) {
        return;
    }
    if (pixelBuffer) {
        CVPixelBufferRetain(pixelBuffer);
    }
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = pixelBuffer;
}

- (void)setResultPixelBuffer:(CVPixelBufferRef)resultPixelBuffer {
    if (_resultPixelBuffer &&
        resultPixelBuffer &&
        CFEqual(resultPixelBuffer, _resultPixelBuffer)) {
        return;
    }
    if (resultPixelBuffer) {
        CVPixelBufferRetain(resultPixelBuffer);
    }
    if (_resultPixelBuffer) {
        CVPixelBufferRelease(_resultPixelBuffer);
    }
    _resultPixelBuffer = resultPixelBuffer;
}

- (MFPixelBufferHelper *)pixelBufferHelper {
    if (!_pixelBufferHelper) {
        EAGLContext *context = [[SourceEAGLContext sharedInstance] currentContext];
        _pixelBufferHelper = [[MFPixelBufferHelper alloc] initWithContext:context];
    }
    return _pixelBufferHelper;
}


- (CIContext *)context {
    if (!_context) {
        _context = [[CIContext alloc] init];
    }
    return _context;
}


#pragma mark - Public

- (CVPixelBufferRef)outputPixelBuffer {
    if (!self.pixelBuffer) {
        return nil;
    }
    [self startRendering];
    return self.resultPixelBuffer;
}


#pragma mark - Private

/// 开始渲染视频图像
- (void)startRendering {
    // 可以对比下两种渲染方式
//    CVPixelBufferRef pixelBuffer = [self renderByGPUImage:self.pixelBuffer];  // GPUImage
    CVPixelBufferRef pixelBuffer = [self renderByCIImage:self.pixelBuffer];  // CIImage
    self.resultPixelBuffer = pixelBuffer;
    CVPixelBufferRelease(pixelBuffer);
}

// 用 CIImage 加滤镜
- (CVPixelBufferRef)renderByCIImage:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferRetain(pixelBuffer);

    CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                             CVPixelBufferGetHeight(pixelBuffer));
    CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
    // 加一层淡黄色滤镜
    CIImage *filterImage = [CIImage imageWithColor:[CIColor colorWithRed:255.0 / 255
                                                                   green:0 / 255
                                                                    blue:0 / 255
                                                                   alpha:0.5]];
    image = [filterImage imageByCompositingOverImage:image];

    CVPixelBufferRef output = [self.pixelBufferHelper createPixelBufferWithSize:size];
    [self.context render:image toCVPixelBuffer:output];

    CVPixelBufferRelease(pixelBuffer);
    return output;
}

void runSynchronouslyOnVideoProcessingQueue(void (^block)(void))
{
    dispatch_queue_t videoProcessingQueue = [SourceEAGLContext sharedContextQueue];
#if !OS_OBJECT_USE_OBJC
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == videoProcessingQueue)
#pragma clang diagnostic pop
#else
    if (dispatch_get_specific([SourceEAGLContext contextKey]))
#endif
    {
        block();
    }else
    {
        dispatch_sync(videoProcessingQueue, block);
    }
}

// 用 GPUImage 加滤镜
//- (CVPixelBufferRef)renderByGPUImage2:(CVPixelBufferRef)pixelBuffer {
//    CVPixelBufferRetain(pixelBuffer);
//
//    __block CVPixelBufferRef output = nil;
//    runSynchronouslyOnVideoProcessingQueue(^{
//        [GPUImageContext useImageProcessingContext];
//
//        GLuint textureID = [self.pixelBufferHelper convertYUVPixelBufferToTexture:pixelBuffer];
//        CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
//                                 CVPixelBufferGetHeight(pixelBuffer));
//
//        [GPUImageContext setActiveShaderProgram:nil];
//        GPUImageTextureInput *textureInput = [[GPUImageTextureInput alloc] initWithTexture:textureID size:size];
//        GPUImageGlassSphereFilter *filter = [[GPUImageGlassSphereFilter alloc] init];
//        [textureInput addTarget:filter];
//        GPUImageTextureOutput *textureOutput = [[GPUImageTextureOutput alloc] init];
//        [filter addTarget:textureOutput];
//        [textureInput processTextureWithFrameTime:kCMTimeZero];
//
//        output = [self.pixelBufferHelper convertTextureToPixelBuffer:textureOutput.texture
//                                                         textureSize:size];
//
//        [textureOutput doneWithTexture];
//
//        glDeleteTextures(1, &textureID);
//    });
//    CVPixelBufferRelease(pixelBuffer);
//
//    return output;
//}

@end
