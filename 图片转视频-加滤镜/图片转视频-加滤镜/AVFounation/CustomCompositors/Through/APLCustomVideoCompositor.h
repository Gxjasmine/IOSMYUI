/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Custom video compositor class implementing the AVVideoCompositing protocol.
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface APLCustomVideoCompositor : NSObject <AVVideoCompositing>
@property (nonatomic, assign) int type;
@end

@interface APLCrossDissolveCompositor : APLCustomVideoCompositor

@end

@interface APLDiagonalWipeCompositor : APLCustomVideoCompositor

@end
