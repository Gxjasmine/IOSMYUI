//
//  TemplateVideoCompositionInstruction.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
typedef NS_ENUM(NSInteger, TemplateType)
{
    kTemplateTypeOne = 0,
    kTemplateTypeTwo,
    kTemplateTypeThree,
    kTemplateTypeFour
};


NS_ASSUME_NONNULL_BEGIN

@interface TemplateVideoCompositionInstruction  : NSObject <AVVideoCompositionInstruction>

@property (nonatomic, assign) CMTimeRange timeRange;
@property (nonatomic, assign) BOOL enablePostProcessing;
@property (nonatomic) BOOL containsTweening;
@property (nonatomic, assign) CMTime currTime;
@property (nonatomic, assign) TemplateType mTemplateType;

@property (nonatomic, readonly, nullable) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, readonly) CMPersistentTrackID passthroughTrackID;

@property (nonatomic, copy) NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions;

- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange;
- (instancetype)initTransitionWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange;

/// 处理 pixelBuffer，并返回结果
- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

NS_ASSUME_NONNULL_END
