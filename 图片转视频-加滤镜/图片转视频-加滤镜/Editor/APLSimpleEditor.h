/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple editor sets up an AVMutableComposition using supplied clips and time ranges. It also sets up an AVVideoComposition to perform custom compositor rendering.
 */

#import <Foundation/Foundation.h>

#import <CoreMedia/CMTime.h>

@class AVPlayerItem, AVAssetExportSession,AVMutableComposition;

@interface APLSimpleEditor : NSObject

// Set these properties before building the composition objects.
@property (nonatomic, copy) NSArray *clips; // array of AVURLAssets
@property (nonatomic, copy) NSArray *clipTimeRanges; // array of CMTimeRanges stored in NSValues.

@property (nonatomic) NSInteger transitionType;
@property (nonatomic) CMTime transitionDuration;

// s视频融合
- (void)buildCompositionObjectsForPlayback:(BOOL)forPlayback;

//视频合并，后面一个开头添加灵魂出窍
- (void)buildCompositionObjectsMerger;

//视频合并，后面一个开头慢放
- (void)buildCompositionObjectsScale;

- (void)buildCompositionObjectsModel01;

- (void)buildCompositionObjectsModel02;

- (void)buildCompositionObjectsModel03;

- (void)buildCompositionObjectsModel04;

- (void)buildCompositionObjectsModel05;

- (void)buildCompositionObjectsModel06;

- (AVAssetExportSession*)assetExportSessionWithPreset:(NSString*)presetName;

- (AVPlayerItem *)playerItem;
- (AVMutableComposition *)playerComposition;
@end
