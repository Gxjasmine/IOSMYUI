/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Custom video compositor class implementing the AVVideoCompositing protocol.
 */

#import "APLCustomVideoCompositor.h"
#import "APLCustomVideoCompositionInstruction.h"
#import "APLDiagonalWipeRenderer.h"
#import "APLCrossDissolveRenderer.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import "MixFilter.h"
#import "CustonFilter.h"
#import "Tem1MixFilter.h"
#import "TemplateVideoCompositionInstruction.h"
#import "CustomVideoCompositionInstruction.h"

@interface APLCustomVideoCompositor()
{
	BOOL								_shouldCancelAllRequests;
	BOOL								_renderContextDidChange;
	dispatch_queue_t					_renderingQueue;
	dispatch_queue_t					_renderContextQueue;
	AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
}

@property (nonatomic, strong) APLOpenGLRenderer *oglRenderer;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) CustonFilter *filter;

@end

@implementation APLCrossDissolveCompositor

- (id)init
{
	self = [super init];
	
	if (self) {
		self.oglRenderer = [[APLCrossDissolveRenderer alloc] init];
        self.filter = [[Tem1MixFilter alloc] init];
	}
	
	return self;
}

- (void)setType:(int)type{

    if (type == 0) {
        self.filter = [[MixFilter alloc] init];

    }else if (type == 1){
        self.filter = [[Tem1MixFilter alloc] init];

    }else if (type == 2){
        self.filter = [[Tem1MixFilter alloc] init];

    }

}

@end

@implementation APLDiagonalWipeCompositor

- (id)init
{
	self = [super init];
	
	if (self) {
		self.oglRenderer = [[APLDiagonalWipeRenderer alloc] init];
	}
	
	return self;
}

@end

@implementation APLCustomVideoCompositor

#pragma mark - AVVideoCompositing protocol

- (id)init
{
	self = [super init];
	if (self)
	{
		_renderingQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.renderingqueue", DISPATCH_QUEUE_SERIAL); 
		_renderContextQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
		_renderContextDidChange = NO;
	}
	return self;
}

- (NSDictionary *)sourcePixelBufferAttributes
{
	return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
			  (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
	return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
			  (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
	dispatch_sync(_renderContextQueue, ^() {
		_renderContext = newRenderContext;
		_renderContextDidChange = YES;
	});
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
	@autoreleasepool {
		dispatch_async(_renderingQueue,^() {
			
			// Check if all pending requests have been cancelled
            if (self->_shouldCancelAllRequests) {
				[request finishCancelledRequest];
			} else {
				NSError *err = nil;
				// Get the next rendererd pixel buffer
				CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
				
				if (resultPixels) {
					// The resulting pixelbuffer from OpenGL renderer is passed along to the request
					[request finishWithComposedVideoFrame:resultPixels];
					CFRelease(resultPixels);
				} else {
					[request finishWithError:err];
				}
			}
		});
	}
}

- (void)cancelAllPendingVideoCompositionRequests
{
	// pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
	_shouldCancelAllRequests = YES;
	
	dispatch_barrier_async(_renderingQueue, ^() {
		// start accepting requests again
        self->_shouldCancelAllRequests = NO;
	});
}

#pragma mark - Utilities

static Float64 factorForTimeInRange(CMTime time, CMTimeRange range) /* 0.0 -> 1.0 */
{
	CMTime elapsed = CMTimeSubtract(time, range.start);
	return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
    CVPixelBufferRef dstPixels = nil;
    // tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
    // 0.0 indicates the time at first frame in that videoComposition timeRange
    // 1.0 indicates the time at last frame in that videoComposition timeRange
    //CMTime elapsed = CMTimeSubtract(time, range.start);
    //  return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
    float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
    NSLog(@"--------------000000-----------tweenFactor:%lf",tweenFactor);

    id currentInstruction2 = request.videoCompositionInstruction;

    if ([currentInstruction2 isKindOfClass:[CustomVideoCompositionInstruction class]]) {
        CustomVideoCompositionInstruction *videoCompositionInstruction = (CustomVideoCompositionInstruction *)request.videoCompositionInstruction;

        CMTime compositionTime = request.compositionTime;
         CMTimeRange InstructionTime = request.videoCompositionInstruction.timeRange;
        CMTime elapsed = CMTimeSubtract(compositionTime, InstructionTime.start);
         Float64 dd = CMTimeGetSeconds(elapsed);
         videoCompositionInstruction.currTime = elapsed;

        CMPersistentTrackID backgroundTrackID = videoCompositionInstruction.backgroundTrackID;

        if (backgroundTrackID) {
            CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:backgroundTrackID];
            if (backgroundSourceBuffer) {
                NSLog(@"----backgPixelBuffer");

                CMPersistentTrackID trackID = videoCompositionInstruction.foregroundTrackID;
                //当前帧的原始图像
                CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:trackID];

                CMTime compositionTime = request.compositionTime;
                CMTimeRange InstructionTime = request.videoCompositionInstruction.timeRange;
                CMTime elapsed = CMTimeSubtract(compositionTime, InstructionTime.start);
                Float64 dd = CMTimeGetSeconds(elapsed);
                _filter.currTime = elapsed;
                size_t num =  CVPixelBufferGetPlaneCount(foregroundSourceBuffer);
                size_t num2 =  CVPixelBufferGetPlaneCount(backgroundSourceBuffer);
                self.filter.pixelBuffer = foregroundSourceBuffer;
                self.filter.backgpixelBuffer = backgroundSourceBuffer;

                CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer;
                CVPixelBufferRetain(outputPixelBuffer);
                if (!outputPixelBuffer) {
                    CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
                    return emptyPixelBuffer;
                } else {
                    return outputPixelBuffer;
                }
            }
        }

        CMPersistentTrackID trackID = videoCompositionInstruction.foregroundTrackID;
        //当前帧的原始图像
        CVPixelBufferRef sourcePixelBuffer = [request sourceFrameByTrackID:trackID];
        CVPixelBufferRef resultPixelBuffer = [videoCompositionInstruction applyPixelBuffer:sourcePixelBuffer];
        size_t num =  CVPixelBufferGetPlaneCount(sourcePixelBuffer);
        NSLog(@"--------------11111----------num：%zu",num);

        if (!resultPixelBuffer) {
            CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
            return emptyPixelBuffer;
        } else {
            return resultPixelBuffer;
        }
    }
    NSLog(@"--------------222222-----------");

    APLCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;

//    APLCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;

    // Source pixel buffers are used as inputs while rendering the transition
    CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.foregroundTrackID];
    CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.backgroundTrackID];

    // Destination pixel buffer into which we render the output
    //    CMTime compositionTime = request.compositionTime;
    //     CMTimeRange InstructionTime = request.videoCompositionInstruction.timeRange;
    //    CMTime elapsed = CMTimeSubtract(compositionTime, InstructionTime.start);
    //     Float64 dd = CMTimeGetSeconds(elapsed);
    //     _filter.currTime = elapsed;
    //        size_t num =  CVPixelBufferGetPlaneCount(foregroundSourceBuffer);
    //        size_t num2 =  CVPixelBufferGetPlaneCount(backgroundSourceBuffer);
    //    self.filter.pixelBuffer = foregroundSourceBuffer;
    //    self.filter.backgpixelBuffer = backgroundSourceBuffer;
    //
    //    CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer;
    //    CVPixelBufferRetain(outputPixelBuffer);
    //    if (!outputPixelBuffer) {
    //             CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
    //             return emptyPixelBuffer;
    //         } else {
    //             return outputPixelBuffer;
    //         }

    dstPixels = [_renderContext newPixelBuffer];

    // Recompute normalized render transform everytime the render context changes
    if (_renderContextDidChange) {
        // The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
        // But since in this sample we render using OpenGLES which has its coordinate system between [-1, 1] we compute a normalized transform
        CGSize renderSize = _renderContext.size;
        CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(dstPixels), CVPixelBufferGetHeight(dstPixels));
        CGAffineTransform renderContextTransform = {renderSize.width/2, 0, 0, renderSize.height/2, renderSize.width/2, renderSize.height/2};
        CGAffineTransform destinationTransform = {2/destinationSize.width, 0, 0, 2/destinationSize.height, -1, -1};
        CGAffineTransform normalizedRenderTransform = CGAffineTransformConcat(CGAffineTransformConcat(renderContextTransform, _renderContext.renderTransform), destinationTransform);
        _oglRenderer.renderTransform = normalizedRenderTransform;

        _renderContextDidChange = NO;
    }

    if ([self supportsFastTextureUpload]) {
        NSLog(@"支持YUV");
    }else {
        NSLog(@"不支持YUV");
        CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
        return emptyPixelBuffer;
    }

    size_t num =  CVPixelBufferGetPlaneCount(foregroundSourceBuffer);
    size_t num2 =  CVPixelBufferGetPlaneCount(backgroundSourceBuffer);

    if (backgroundSourceBuffer == nil) {
        CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
        return emptyPixelBuffer;
    }

    [_oglRenderer renderPixelBuffer:dstPixels usingForegroundSourceBuffer:foregroundSourceBuffer andBackgroundSourceBuffer:backgroundSourceBuffer forTweenFactor:tweenFactor];
    if (!dstPixels) {
             CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
             return emptyPixelBuffer;
         } else {
             return dstPixels;
         }
    return dstPixels;
}

- (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop

#endif
}



/// 创建一个空白的视频帧
- (CVPixelBufferRef)createEmptyPixelBuffer {
    CVPixelBufferRef pixelBuffer = [_renderContext newPixelBuffer];
    CIImage *image = [CIImage imageWithColor:[CIColor colorWithRed:0 green:0 blue:0 alpha:0]];
    [self.ciContext render:image toCVPixelBuffer:pixelBuffer];
    return pixelBuffer;
}

- (CIContext *)ciContext {
    if (!_ciContext) {
        _ciContext = [[CIContext alloc] init];
    }
    return _ciContext;
}

@end
