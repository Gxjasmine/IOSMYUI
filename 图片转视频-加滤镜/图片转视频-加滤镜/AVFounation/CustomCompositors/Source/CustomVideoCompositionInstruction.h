//
//  CustomVideoCompositionInstruction.h
//  testVideoFilter
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction>
@property CMPersistentTrackID foregroundTrackID;
@property CMPersistentTrackID backgroundTrackID;

@property (nonatomic, assign) CMTimeRange timeRange;
@property (nonatomic, assign) BOOL enablePostProcessing;
@property (nonatomic) BOOL containsTweening;
@property (nonatomic, assign) CMTime currTime;
@property (nonatomic, assign) CMTimeRange filterTimeRange;
@property (nonatomic, strong) NSMutableArray *filterTimeRanges;
@property (nonatomic, strong) NSMutableArray *filters;

@property (nonatomic, readonly, nullable) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, readonly) CMPersistentTrackID passthroughTrackID;

@property (nonatomic, copy) NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions;

- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange;
- (instancetype)initTransitionWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange;

/// 处理 pixelBuffer，并返回结果
- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
