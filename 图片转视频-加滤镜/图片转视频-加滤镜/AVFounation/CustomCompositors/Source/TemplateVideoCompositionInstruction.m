//
//  TemplateVideoCompositionInstruction.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/1.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "TemplateVideoCompositionInstruction.h"
#import "Template01.h"
#import "CustomTemlate.h"
#import "Template02.h"

@interface TemplateVideoCompositionInstruction ()
@property (nonatomic, strong) CustomTemlate * teml;
@end
@implementation TemplateVideoCompositionInstruction
- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _passthroughTrackID = passthroughTrackID;
        _timeRange = timeRange;
        _requiredSourceTrackIDs = @[];
        _containsTweening = NO;
        _enablePostProcessing = NO;
        _mTemplateType = kTemplateTypeOne;
        _teml = [[Template01 alloc] init];
    }
    return self;
}

- (instancetype)initTransitionWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _requiredSourceTrackIDs = sourceTrackIDs;
        _timeRange = timeRange;
        _passthroughTrackID = kCMPersistentTrackID_Invalid;
        _containsTweening = YES;
        _enablePostProcessing = NO;
        _mTemplateType = kTemplateTypeOne;
        _teml = [[Template01 alloc] init];

    }
    return self;
}

-(void)setMTemplateType:(TemplateType)mTemplateType{
    _mTemplateType = mTemplateType;
    switch (mTemplateType) {
        case kTemplateTypeOne:
            _teml = [[Template01 alloc] init];

            break;
        case kTemplateTypeTwo:
            _teml = [[Template02 alloc] init];

            break;
        default:
            break;
    }

}

#pragma mark - Public

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer {

    return [self.teml applyPixelBuffer:pixelBuffer withTime:self.currTime];
}

@end
