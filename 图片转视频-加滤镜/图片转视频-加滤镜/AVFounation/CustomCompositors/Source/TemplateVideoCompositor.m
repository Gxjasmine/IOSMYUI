//
//  TemplateVideoCompositor.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "TemplateVideoCompositor.h"
#import <CoreImage/CoreImage.h>
#import "TemplateVideoCompositionInstruction.h"

@interface TemplateVideoCompositor ()

@property (nonatomic, strong) dispatch_queue_t renderContextQueue;
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, assign) BOOL shouldCancelAllRequests;

@property (nonatomic, strong) AVVideoCompositionRenderContext *renderContext;
@property (nonatomic, strong) CIContext *ciContext;

@end

@implementation TemplateVideoCompositor

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourcePixelBufferAttributes = @{(id)kCVPixelBufferOpenGLCompatibilityKey: @YES,
                                         (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        _requiredPixelBufferAttributesForRenderContext = @{(id)kCVPixelBufferOpenGLCompatibilityKey: @YES,
                                                           (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};

        _renderContextQueue = dispatch_queue_create("com.lymamli.videofilter.rendercontextqueue", 0);
        _renderingQueue = dispatch_queue_create("com.lymamli.videofilter.renderingqueue", 0);
    }
    return self;
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
    dispatch_sync(self.renderContextQueue, ^{
        self.renderContext = newRenderContext;
    });
}

//最关键是 startVideoCompositionRequest 方法的实现：
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest {
    dispatch_async(self.renderingQueue, ^{
        @autoreleasepool {
            if (self.shouldCancelAllRequests) {
                [asyncVideoCompositionRequest finishCancelledRequest];
            } else {
                CVPixelBufferRef resultPixels = [self newRenderdPixelBufferForRequest:asyncVideoCompositionRequest];
                if (resultPixels) {
                    [asyncVideoCompositionRequest finishWithComposedVideoFrame:resultPixels];
                    CVPixelBufferRelease(resultPixels);
                } else {
                    NSError *error = [NSError errorWithDomain:@"com.lymamli.panorama.videocompositor" code:0 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Composition request new pixel buffer failed.", nil)}];
                    [asyncVideoCompositionRequest finishWithError:error];
                    NSLog(@"%@", error);
                }
            }
        }
    });
}

- (void)cancelAllPendingVideoCompositionRequests {
    self.shouldCancelAllRequests = YES;
    dispatch_barrier_async(self.renderingQueue, ^{
        self.shouldCancelAllRequests = NO;
    });
}

#pragma mark - Utilities

static Float64 factorForTimeInRange(CMTime time, CMTimeRange range) /* 0.0 -> 1.0 */
{
    CMTime elapsed = CMTimeSubtract(time, range.start);
    return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

#pragma mark - Private   https://www.jb51.net/article/182735.htm
//通过 newRenderdPixelBufferForRequest 方法从 AVAsynchronousVideoCompositionRequest 中获取到处理后的 CVPixelBufferRef 后输出，
- (CVPixelBufferRef)newRenderdPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request {

    TemplateVideoCompositionInstruction *videoCompositionInstruction = (TemplateVideoCompositionInstruction *)request.videoCompositionInstruction;
//
//    NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions = videoCompositionInstruction.layerInstructions;
//    CMPersistentTrackID trackID = layerInstructions.firstObject.trackID;
    CMPersistentTrackID trackID = [request.sourceTrackIDs.firstObject intValue];
   CMTime compositionTime = request.compositionTime;
    CMTimeRange InstructionTime = request.videoCompositionInstruction.timeRange;

    CMTime elapsed = CMTimeSubtract(compositionTime, InstructionTime.start);
    Float64 dd = CMTimeGetSeconds(elapsed);
    videoCompositionInstruction.currTime = elapsed;
    Float64 dd2 = CMTimeGetSeconds(compositionTime);
//    NSLog(@"--------------compositionTime = %f-----------elapsed:%lf",dd2,dd);
    //播放进度
//    float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
//    NSLog(@"--------------000000-----------tweenFactor:%lf",tweenFactor);
    //当前帧的原始图像
    CVPixelBufferRef sourcePixelBuffer = [request sourceFrameByTrackID:trackID];

//    if (!sourcePixelBuffer) {
//          CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
//        NSLog(@"emptyPixelBuffer");
//          return emptyPixelBuffer;
//      } else {
//          CVPixelBufferRetain(sourcePixelBuffer);
//
//          return sourcePixelBuffer;
//      }

    CVPixelBufferRef resultPixelBuffer = [videoCompositionInstruction applyPixelBuffer:sourcePixelBuffer];

    if (!resultPixelBuffer) {
        CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
        return emptyPixelBuffer;
    } else {
        return resultPixelBuffer;
    }
}

/// 创建一个空白的视频帧
- (CVPixelBufferRef)createEmptyPixelBuffer {
    CVPixelBufferRef pixelBuffer = [self.renderContext newPixelBuffer];
    CIImage *image = [CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:0]];
    [self.ciContext render:image toCVPixelBuffer:pixelBuffer];
    return pixelBuffer;
}

#pragma mark - Accessors

- (CIContext *)ciContext {
    if (!_ciContext) {
        _ciContext = [[CIContext alloc] init];
    }
    return _ciContext;
}

@end
