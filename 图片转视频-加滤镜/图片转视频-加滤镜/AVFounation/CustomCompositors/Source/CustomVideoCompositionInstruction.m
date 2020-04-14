//
//  CustomVideoCompositionInstruction.m
//  testVideoFilter
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "CustonFilter.h"
#import "ScaleFilter.h"
#import "RotateFilter.h"
#import "MoveAndRotateFilter.h"
#import "MixFilter.h"
#import "SouloutFilter.h"
#import "VertigoFilter.h"
#import "CubeFilter.h"

#import "CustomVideoCompositionInstruction.h"

@interface CustomVideoCompositionInstruction ()

@property (nonatomic, strong) CustonFilter *filter;
@property (nonatomic, assign) int sedd;

@end

@implementation CustomVideoCompositionInstruction

- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _passthroughTrackID = passthroughTrackID;
        _timeRange = timeRange;
        _requiredSourceTrackIDs = @[];
        _containsTweening = NO;
        _enablePostProcessing = NO;
        _filter = [[ScaleFilter alloc] init];
        _sedd = 0;
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
        _filter = [[ScaleFilter alloc] init];
        _sedd = 0;

    }
    return self;
}

-(void)setFilterTimeRanges:(NSMutableArray *)filterTimeRanges{
    _filterTimeRanges = filterTimeRanges;
//    [_filterTimeRanges addObject:_timeRange];
//    _filterTimeRange = (CMTimeRange)_filterTimeRanges.firstObject;
}

#pragma mark - Public

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer {
//    _sedd += 1;

//         CVPixelBufferRetain(pixelBuffer);
//        return pixelBuffer;
//    }
//    self.timeRange --- 时间戳


    if (CMTIMERANGE_IS_VALID(self.filterTimeRange)) {

        NSLog(@"applyPixelBuffer IS_VALID");
        /***
        如果time1小于time2，则返回-1。如果他们返回0
        是相等的。如果time1大于time2，则返回1。
        两个CMTimes的数值关系(-1 =小于，1 =大于，0 =相等)。
        */
        int a =  CMTimeCompare(self.currTime, self.filterTimeRange.start);

        CMTime TOTAL =  CMTimeAdd(self.filterTimeRange.start, self.filterTimeRange.duration);

        float dd = CMTimeGetSeconds(TOTAL);
        float currTime = CMTimeGetSeconds(self.currTime);

        int b =  CMTimeCompare(self.currTime, CMTimeAdd(self.filterTimeRange.start, self.filterTimeRange.duration));
        if (a>= 0 && b <= 0) {
            NSLog(@" ----111111");
            self.filter.pixelBuffer = pixelBuffer;
            self.filter.currTime = self.currTime;
            self.filter.pixelBuffer = pixelBuffer;
            CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer;
            CVPixelBufferRetain(outputPixelBuffer);

            return outputPixelBuffer;
        }else{
            NSLog(@" ----222222");

            CVPixelBufferRetain(pixelBuffer);
            return pixelBuffer;
        }

    }else{
        NSLog(@"applyPixelBuffer IS_NOT_VALID");

        self.filter.pixelBuffer = pixelBuffer;
        self.filter.currTime = self.currTime;
        self.filter.pixelBuffer = pixelBuffer;
        CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer;
        CVPixelBufferRetain(outputPixelBuffer);

        return outputPixelBuffer;
    }
}

@end
