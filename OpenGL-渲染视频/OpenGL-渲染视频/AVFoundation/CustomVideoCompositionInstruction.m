//
//  CustomVideoCompositionInstruction.m
//  testVideoFilter
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import "CustomFilter.h"

#import "CustomVideoCompositionInstruction.h"

@interface CustomVideoCompositionInstruction ()

@property (nonatomic, strong) CustomFilter *filter;
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
        _filter = [[CustomFilter alloc] init];
        _sedd = 0;
    }
    return self;
}

- (instancetype)initWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange {
    self = [super init];
    if (self) {
        _requiredSourceTrackIDs = sourceTrackIDs;
        _timeRange = timeRange;
        _passthroughTrackID = kCMPersistentTrackID_Invalid;
        _containsTweening = YES;
        _enablePostProcessing = NO;
        _filter = [[CustomFilter alloc] init];
        _sedd = 0;

    }
    return self;
}

#pragma mark - Public

- (CVPixelBufferRef)applyPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    _sedd += 1;

//    if (_sedd > 500) {//原图像
//         CVPixelBufferRetain(pixelBuffer);
//        return pixelBuffer;
//    }
    self.filter.pixelBuffer = pixelBuffer;
    if (_sedd > 180 && _sedd < 360) {
            CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer2;
           CVPixelBufferRetain(outputPixelBuffer);
           NSLog(@"_sedd = %d",_sedd);

           return outputPixelBuffer;
    }else if (_sedd > 360 ) {
        CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer3;
               CVPixelBufferRetain(outputPixelBuffer);
               NSLog(@"_sedd = %d",_sedd);

               return outputPixelBuffer;
    }

    CVPixelBufferRef outputPixelBuffer = self.filter.outputPixelBuffer;
    CVPixelBufferRetain(outputPixelBuffer);
    NSLog(@"_sedd = %d",_sedd);

    return outputPixelBuffer;
}

@end
