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
#import "CustomVideoCompositionInstruction.h"

#import <CoreVideo/CoreVideo.h>

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

@end

@implementation APLCrossDissolveCompositor

- (id)init
{
	self = [super init];
	
	if (self) {
		self.oglRenderer = [[APLCrossDissolveRenderer alloc] init];
	}
	
	return self;
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
			if (_shouldCancelAllRequests) {
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
		_shouldCancelAllRequests = NO;
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

	id currentInstruction2 = request.videoCompositionInstruction;

    if (![currentInstruction2 isKindOfClass:[APLCustomVideoCompositionInstruction class]]) {
        CustomVideoCompositionInstruction *videoCompositionInstruction = (CustomVideoCompositionInstruction *)request.videoCompositionInstruction;

        NSLog(@"--------------11111-----------tweenFactor:%lf",tweenFactor);

        CMPersistentTrackID trackID = videoCompositionInstruction.foregroundTrackID;
        //当前帧的原始图像
        CVPixelBufferRef sourcePixelBuffer = [request sourceFrameByTrackID:trackID];
        CVPixelBufferRef resultPixelBuffer = [videoCompositionInstruction applyPixelBuffer:sourcePixelBuffer];

        if (!resultPixelBuffer) {
            CVPixelBufferRef emptyPixelBuffer = [self createEmptyPixelBuffer];
            return emptyPixelBuffer;
        } else {
            return resultPixelBuffer;
        }
    }
    NSLog(@"--------------222222-----------");

    APLCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;

//	APLCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
	
	// Source pixel buffers are used as inputs while rendering the transition
	CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.foregroundTrackID];
	CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.backgroundTrackID];
	
	// Destination pixel buffer into which we render the output
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
	
	[_oglRenderer renderPixelBuffer:dstPixels usingForegroundSourceBuffer:foregroundSourceBuffer andBackgroundSourceBuffer:backgroundSourceBuffer forTweenFactor:tweenFactor];
	
	return dstPixels;
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
