/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple editor sets up an AVMutableComposition using supplied clips and time ranges. It also sets up an AVVideoComposition to perform custom compositor rendering.
 */

#import "APLSimpleEditor.h"
#import "APLCustomVideoCompositor.h"
#import "APLCustomVideoCompositionInstruction.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "CustomVideoCompositionInstruction.h"
#import "FWCustomVideoCompositor.h"
#import "TemplateVideoCompositor.h"
#import "TemplateVideoCompositionInstruction.h"

@interface APLSimpleEditor ()

@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@end



@implementation APLSimpleEditor


- (void)buildTransitionComposition2:(AVMutableComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition
{
	CMTime nextClipStartTime = kCMTimeZero;
	NSInteger i;
	NSUInteger clipsCount = [_clips count];
	
	// Make transitionDuration no greater than half the shortest clip duration.
	CMTime transitionDuration = self.transitionDuration;
	for (i = 0; i < clipsCount; i++ ) {
		NSValue *clipTimeRange = [_clipTimeRanges objectAtIndex:i];
		if (clipTimeRange) {
			CMTime halfClipDuration = [clipTimeRange CMTimeRangeValue].duration;
			halfClipDuration.timescale *= 2; // You can halve a rational by doubling its denominator.
			transitionDuration = CMTimeMinimum(transitionDuration, halfClipDuration);
		}
	}
	
	// Add two video tracks and two audio tracks.
	AVMutableCompositionTrack *compositionVideoTracks[2];
	AVMutableCompositionTrack *compositionAudioTracks[2];
	compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	compositionAudioTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
	compositionAudioTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
	
	CMTimeRange *passThroughTimeRanges = alloca(sizeof(CMTimeRange) * clipsCount);
	CMTimeRange *transitionTimeRanges = alloca(sizeof(CMTimeRange) * clipsCount);
    CMTimeRange durationRanges[2];
    durationRanges[0] = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(8, 1));
    durationRanges[1] = CMTimeRangeMake(CMTimeMakeWithSeconds(5, 1), CMTimeMakeWithSeconds(8, 1));

	// Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
	for (i = 0; i < clipsCount; i++ ) {
		NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...
		AVURLAsset *asset = [_clips objectAtIndex:i];
		NSValue *clipTimeRange = [_clipTimeRanges objectAtIndex:i];
		CMTimeRange timeRangeInAsset;
		if (clipTimeRange)
			timeRangeInAsset = [clipTimeRange CMTimeRangeValue];
		else
			timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, [asset duration]);
		
		AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
		[compositionVideoTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];
		
		AVAssetTrack *clipAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
		[compositionAudioTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:nextClipStartTime error:nil];
		
		// Remember the time range in which this clip should pass through.
		// First clip ends with a transition.
		// Second clip begins with a transition.
		// Exclude that transition from the pass through time ranges.
		passThroughTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration);
		if (i > 0) {
			passThroughTimeRanges[i].start = CMTimeAdd(passThroughTimeRanges[i].start, transitionDuration);
			passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration);
		}
		if (i+1 < clipsCount) {
			passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration);
		}
		
		// The end of this clip will overlap the start of the next by transitionDuration.
		// (Note: this arithmetic falls apart if timeRangeInAsset.duration < 2 * transitionDuration.)
		nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration);
		nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitionDuration);

		// Remember the time range for the transition to the next item.
		if (i+1 < clipsCount) {
			transitionTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, transitionDuration);
		}
	}
	
	// Set up the video composition to perform cross dissolve or diagonal wipe transitions between clips.
	NSMutableArray *instructions = [NSMutableArray array];

	// Cycle between "pass through A", "transition from A to B", "pass through B"
	for (i = 0; i < clipsCount; i++ ) {
		NSInteger alternatingIndex = i % 2; // alternating targets
		
		if (videoComposition.customVideoCompositorClass) {

//			APLCustomVideoCompositionInstruction *videoInstruction = [[APLCustomVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[alternatingIndex].trackID forTimeRange:passThroughTimeRanges[i]];
////           CustomVideoCompositionInstruction *videoInstruction = [[CustomVideoCompositionInstruction alloc] initWithPassthroughTrackID:compositionVideoTracks[alternatingIndex].trackID timeRange:passThroughTimeRanges[i]];
//            [instructions addObject:videoInstruction];

            CMTimeRange  range = passThroughTimeRanges[i];
            float start = CMTimeGetSeconds(range.start);
            float sdd = CMTimeGetSeconds(range.duration);
            CustomVideoCompositionInstruction *videoInstruction2 = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] timeRange:passThroughTimeRanges[i]];
            //                newInstruction.layerInstructions = instruction.layerInstructions;
            //                [instructions addObject:videoInstruction];

            // First track -> Foreground track while compositing
            videoInstruction2.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
            // Second track -> Background track while compositing
            videoInstruction2.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;

            [instructions addObject:videoInstruction2];

        }
		else {
			// Pass through clip i.
			AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
			passThroughInstruction.timeRange = passThroughTimeRanges[i];
			AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[alternatingIndex]];
		
			passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayer];
			[instructions addObject:passThroughInstruction];
		}
		
		if (i+1 < clipsCount) {
			// Add transition from clip i to clip i+1.
			if (videoComposition.customVideoCompositorClass) {
				APLCustomVideoCompositionInstruction *videoInstruction = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] forTimeRange:transitionTimeRanges[i]];

				if (alternatingIndex == 0) {
					// First track -> Foreground track while compositing
					videoInstruction.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
					// Second track -> Background track while compositing
					videoInstruction.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;
                }
                [instructions addObject:videoInstruction];        

//                CMTimeRange  range = transitionTimeRanges[i];
//                float start = CMTimeGetSeconds(range.start);
//                float sdd = CMTimeGetSeconds(range.duration);
//            APLCustomVideoCompositionInstruction *videoInstruction = [[APLCustomVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[0].trackID forTimeRange:transitionTimeRanges[i]];
//                if (alternatingIndex == 0) {
//                           // First track -> Foreground track while compositing
//                           videoInstruction.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
//                           // Second track -> Background track while compositing
//                           videoInstruction.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;
//                       }
//                [instructions addObject:videoInstruction];
//
//
//                APLCustomVideoCompositionInstruction *videoInstruction2 = [[APLCustomVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[1].trackID forTimeRange:transitionTimeRanges[i]];
//                             if (alternatingIndex == 0) {
//                                        // First track -> Foreground track while compositing
//                                        videoInstruction2.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
//                                        // Second track -> Background track while compositing
//                                        videoInstruction2.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;
//                                    }
//                             [instructions addObject:videoInstruction2];

//
//                CMTimeRange  range = durationRanges[i];
//                float start = CMTimeGetSeconds(range.start);
//                float sdd = CMTimeGetSeconds(range.duration);
//
//                CustomVideoCompositionInstruction *videoInstruction2 = [[CustomVideoCompositionInstruction alloc] initWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] timeRange:range];
//
////                newInstruction.layerInstructions = instruction.layerInstructions;
////                [instructions addObject:videoInstruction];
//
//                if (alternatingIndex == 0) {
//                    // First track -> Foreground track while compositing
//                    videoInstruction2.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
//                    // Second track -> Background track while compositing
//                    videoInstruction2.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;
//                }
//
//                [instructions addObject:videoInstruction2];
			}
			else {
				AVMutableVideoCompositionInstruction *transitionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
				transitionInstruction.timeRange = transitionTimeRanges[i];
				AVMutableVideoCompositionLayerInstruction *fromLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[alternatingIndex]];
				AVMutableVideoCompositionLayerInstruction *toLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[1-alternatingIndex]];
				
				transitionInstruction.layerInstructions = [NSArray arrayWithObjects:fromLayer, toLayer, nil];
				[instructions addObject:transitionInstruction];
			}
		}
	}

	videoComposition.instructions = instructions;

}

- (void)buildCompositionObjectsForPlayback:(BOOL)forPlayback
{
	if ( (_clips == nil) || [_clips count] == 0 ) {
		self.composition = nil;
		self.videoComposition = nil;
		return;
	}
	
	CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
	AVMutableComposition *composition = [AVMutableComposition composition];
	AVMutableVideoComposition *videoComposition = nil;
	
	composition.naturalSize = videoSize;
	
	// With transitions:
	// Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
	// Set up the video composition to cycle between "pass through A", "transition from A to B",
	// "pass through B".
	
	videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [APLCrossDissolveCompositor class];

	[self buildTransitionComposition:composition andVideoComposition:videoComposition];
	
	if (videoComposition) {
		// Every videoComposition needs these properties to be set:
		videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
		videoComposition.renderSize = videoSize;
	}
	
	self.composition = composition;
	self.videoComposition = videoComposition;

}

- (void)buildCompositionObjectsModel06{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        return;
    }
    self.composition = nil;
    self.videoComposition = nil;

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [APLCrossDissolveCompositor class];

    CMTime nextClipStartTime = kCMTimeZero;
    NSUInteger count = [_clips count];
    NSInteger i;

    CMTimeRange clipTimeRange = kCMTimeRangeZero;

    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[3];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    compositionVideoTracks[2] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTimeRange *passThroughTimeRanges = alloca(sizeof(CMTimeRange) * count);
    CMTimeRange *transitionTimeRanges = alloca(sizeof(CMTimeRange) * count);
    CMTime transitonDuration = CMTimeMake(2 * 1000, 1000);


        AVURLAsset *videoAsset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"透明1" ofType:@"mp4"]]];
            NSArray *tracks1 = [videoAsset1 tracksWithMediaType:AVMediaTypeVideo];
            AVAssetTrack *clipVideoTrack1 = [tracks1 firstObject];
    //       CMTimeScale naturalTimeScale =  clipVideoTrack.naturalTimeScale;
    //       float aa = clipVideoTrack.nominalFrameRate;

         CMTimeRange  clipTimeRange1 = [clipVideoTrack1 timeRange];

    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < count; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...

        AVURLAsset *videoAsset = [_clips objectAtIndex:i];
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *clipVideoTrack = [tracks firstObject];
//       CMTimeScale naturalTimeScale =  clipVideoTrack.naturalTimeScale;
//       float aa = clipVideoTrack.nominalFrameRate;

        clipTimeRange = [clipVideoTrack timeRange];

        float duration = CMTimeGetSeconds(clipTimeRange.duration);
        NSLog(@"视频 duration：%lf",duration);

        [compositionVideoTracks[alternatingIndex] insertTimeRange:clipTimeRange ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];

        [compositionVideoTracks[2] insertTimeRange:clipTimeRange1 ofTrack:clipVideoTrack1 atTime:nextClipStartTime error:nil];


        passThroughTimeRanges[i] = CMTimeRangeMake(nextClipStartTime,clipTimeRange.duration);
        if (i > 0) {
            passThroughTimeRanges[i].start = CMTimeAdd(passThroughTimeRanges[i].start,transitonDuration);
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitonDuration);
        }
        if (i+1 < count) {
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitonDuration);
        }

        nextClipStartTime = CMTimeAdd(nextClipStartTime, clipTimeRange.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitonDuration);

        // Remember the time range for the transition to the next item.
        if (i+1 < count) {
            transitionTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, transitonDuration);
        }
    }



    NSMutableArray *instructions = [NSMutableArray array];
    for (i = 0; i < count; i++) {

        NSInteger index = i % 2;
        NSLog(@"customVideoCompositorClass 2222");
        if (videoComposition.customVideoCompositorClass) {

       CustomVideoCompositionInstruction *videoInstruction = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[index].trackID],[NSNumber numberWithInt:compositionVideoTracks[2].trackID]] timeRange:passThroughTimeRanges[i]];
            // First track -> Foreground track while compositing
            videoInstruction.foregroundTrackID = compositionVideoTracks[index].trackID;
            videoInstruction.backgroundTrackID = compositionVideoTracks[2].trackID;

            [instructions addObject:videoInstruction];


            if (i+1 < count) {
                CMTimeRange  range = transitionTimeRanges[i];
//
    APLCustomVideoCompositionInstruction *instruction = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] forTimeRange:transitionTimeRanges[i]];
                // First track -> Foreground track while compositing
                instruction.foregroundTrackID = compositionVideoTracks[index].trackID;
                // Second track -> Background track while compositing
                instruction.backgroundTrackID = compositionVideoTracks[1-index].trackID;

                [instructions addObject:instruction];


            }

        }
    }

    videoComposition.instructions = instructions;
    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;

}


- (void)buildCompositionObjectsModel05{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        return;
    }
    self.composition = nil;
    self.videoComposition = nil;

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [APLCrossDissolveCompositor class];

    CMTime nextClipStartTime = kCMTimeZero;
    NSUInteger count = [_clips count];
    NSInteger i;

    CMTimeRange clipTimeRange = kCMTimeRangeZero;

    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[2];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];


    CMTimeRange *passThroughTimeRanges = alloca(sizeof(CMTimeRange) * count);
    CMTimeRange *transitionTimeRanges = alloca(sizeof(CMTimeRange) * count);
    CMTime transitonDuration = CMTimeMake(2 * 1000, 1000);

    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < count; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...

        AVURLAsset *videoAsset = [_clips objectAtIndex:i];
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *clipVideoTrack = [tracks firstObject];
//       CMTimeScale naturalTimeScale =  clipVideoTrack.naturalTimeScale;
//       float aa = clipVideoTrack.nominalFrameRate;

        clipTimeRange = [clipVideoTrack timeRange];

        float duration = CMTimeGetSeconds(clipTimeRange.duration);
        NSLog(@"视频 duration：%lf",duration);

        [compositionVideoTracks[alternatingIndex] insertTimeRange:clipTimeRange ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];


        passThroughTimeRanges[i] = CMTimeRangeMake(nextClipStartTime,clipTimeRange.duration);
        if (i > 0) {
            passThroughTimeRanges[i].start = CMTimeAdd(passThroughTimeRanges[i].start,transitonDuration);
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitonDuration);
        }
        if (i+1 < count) {
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitonDuration);
        }

        nextClipStartTime = CMTimeAdd(nextClipStartTime, clipTimeRange.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitonDuration);

        // Remember the time range for the transition to the next item.
        if (i+1 < count) {
            transitionTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, transitonDuration);
        }
    }

    NSMutableArray *instructions = [NSMutableArray array];
    for (i = 0; i < count; i++) {

        NSInteger index = i % 2;
        NSLog(@"customVideoCompositorClass 2222");
        if (videoComposition.customVideoCompositorClass) {

       CustomVideoCompositionInstruction *videoInstruction = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[index].trackID]] timeRange:passThroughTimeRanges[i]];
            // First track -> Foreground track while compositing
            videoInstruction.foregroundTrackID = compositionVideoTracks[index].trackID;

            [instructions addObject:videoInstruction];


            if (i+1 < count) {
                CMTimeRange  range = transitionTimeRanges[i];
//
    APLCustomVideoCompositionInstruction *instruction = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] forTimeRange:transitionTimeRanges[i]];
                // First track -> Foreground track while compositing
                instruction.foregroundTrackID = compositionVideoTracks[index].trackID;
                // Second track -> Background track while compositing
                instruction.backgroundTrackID = compositionVideoTracks[1-index].trackID;

                [instructions addObject:instruction];


            }

        }
    }

    videoComposition.instructions = instructions;
    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;

}

- (void)buildCompositionObjectsModel04{
    if ( (_clips == nil) || [_clips count] == 0 ) {

        self.composition = nil;
        self.videoComposition = nil;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

//    videoComposition.customVideoCompositorClass = [APLCrossDissolveCompositor class];
    videoComposition.customVideoCompositorClass = [TemplateVideoCompositor class];

    NSInteger i;
    NSUInteger clipsCount = [_clips count];
    
    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[2];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];


    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < clipsCount; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...

        AVURLAsset *videoAsset = [_clips objectAtIndex:i];
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *clipVideoTrack = [tracks firstObject];
        bgVideoTimeRange = [clipVideoTrack timeRange];

        float duration = CMTimeGetSeconds(bgVideoTimeRange.duration);
        NSLog(@"视频 duration：%lf",duration);

        [compositionVideoTracks[alternatingIndex] insertTimeRange:bgVideoTimeRange ofTrack:clipVideoTrack atTime:kCMTimeZero error:nil];
        [compositionVideoTracks[alternatingIndex] setPreferredTransform:clipVideoTrack.preferredTransform];

        if (i == 0) {//倒数最后一个
            CMTime destinationTimeRange = CMTimeMultiplyByFloat64(bgVideoTimeRange.duration, 5.0);
            [compositionVideoTracks[0] scaleTimeRange:bgVideoTimeRange toDuration:destinationTimeRange];

        }
    }

    bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
    NSMutableArray *instructions = [NSMutableArray array];
//    APLCustomVideoCompositionInstruction *videoInstruction2 = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] forTimeRange:bgVideoTimeRange];


    TemplateVideoCompositionInstruction *videoInstruction2 = [[TemplateVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] timeRange:bgVideoTimeRange];
    videoInstruction2.mTemplateType = kTemplateTypeFive;

    // First track -> Foreground track while compositing
    videoInstruction2.foregroundTrackID = compositionVideoTracks[0].trackID;
    // Second track -> Background track while compositing
    videoInstruction2.backgroundTrackID = compositionVideoTracks[1].trackID;
    videoInstruction2.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);

    [instructions addObject:videoInstruction2];
    videoComposition.instructions = instructions;
    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;

}

- (void)buildCompositionObjectsModel03{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [TemplateVideoCompositor class];

    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    //第一个视频时长
    AVURLAsset *asset = [_clips objectAtIndex:0];
    float duration = CMTimeGetSeconds(asset.duration);

    CMTime timeAdd = kCMTimeZero;
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < clipsCount; i++) {
        AVURLAsset *asset = [_clips objectAtIndex:i];

        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);

        [videoTrack insertTimeRange:video_timeRange ofTrack:clipVideoTrack atTime:timeAdd error:nil];

//        CMTime destinationTimeRange = CMTimeMultiplyByFloat64(asset.duration, 0.3);
//        [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        timeAdd = CMTimeAdd(timeAdd, asset.duration);
        [videoTrack setPreferredTransform:clipVideoTrack.preferredTransform];
    }
     bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, timeAdd);

    NSMutableArray *instructions = [NSMutableArray array];

    TemplateVideoCompositionInstruction *videoInstruction = [[TemplateVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:videoTrack.trackID]] timeRange:bgVideoTimeRange];
    videoInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
    videoInstruction.mTemplateType = kTemplateTypeThree;
    [instructions addObject:videoInstruction];
    videoComposition.instructions = instructions;

    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;
}

- (void)buildCompositionObjectsModel02{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [TemplateVideoCompositor class];

    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    //第一个视频时长
    AVURLAsset *asset = [_clips objectAtIndex:0];
    float duration = CMTimeGetSeconds(asset.duration);

    CMTime timeAdd = kCMTimeZero;
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < clipsCount; i++) {
        AVURLAsset *asset = [_clips objectAtIndex:i];

        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);

        [videoTrack insertTimeRange:video_timeRange ofTrack:clipVideoTrack atTime:timeAdd error:nil];

//        CMTime destinationTimeRange = CMTimeMultiplyByFloat64(asset.duration, 0.3);
//        [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        timeAdd = CMTimeAdd(timeAdd, asset.duration);
        [videoTrack setPreferredTransform:clipVideoTrack.preferredTransform];
        if (i == clipsCount - 1) {//倒数最后一个
            CMTime destinationTimeRange = CMTimeMultiplyByFloat64(video_timeRange.duration, 2);
            [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        }


    }
     bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, timeAdd);

    NSMutableArray *instructions = [NSMutableArray array];

    TemplateVideoCompositionInstruction *videoInstruction = [[TemplateVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:videoTrack.trackID]] timeRange:bgVideoTimeRange];
    videoInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
    videoInstruction.mTemplateType = kTemplateTypeTwo;
    [instructions addObject:videoInstruction];
    videoComposition.instructions = instructions;

    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 10); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;
}
//
- (void)buildCompositionObjectsModel01{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [TemplateVideoCompositor class];

    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    //第一个视频时长
    AVURLAsset *asset = [_clips objectAtIndex:0];
    float duration = CMTimeGetSeconds(asset.duration);

    CMTime timeAdd = kCMTimeZero;
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < clipsCount; i++) {
        AVURLAsset *asset = [_clips objectAtIndex:i];

        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);

        [videoTrack insertTimeRange:video_timeRange ofTrack:clipVideoTrack atTime:timeAdd error:nil];

//        CMTime destinationTimeRange = CMTimeMultiplyByFloat64(asset.duration, 0.3);
//        [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        timeAdd = CMTimeAdd(timeAdd, asset.duration);
        [videoTrack setPreferredTransform:clipVideoTrack.preferredTransform];
        if (i == clipsCount - 1) {//倒数最后一个
            CMTime destinationTimeRange = CMTimeMultiplyByFloat64(video_timeRange.duration, 2);
            [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        }


    }
     bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, timeAdd);

    NSMutableArray *instructions = [NSMutableArray array];

    TemplateVideoCompositionInstruction *videoInstruction = [[TemplateVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:videoTrack.trackID]] timeRange:bgVideoTimeRange];
    videoInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
    [instructions addObject:videoInstruction];
    videoComposition.instructions = instructions;

    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 10); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;
}

//普通播放速率
- (void)buildCompositionObjectsScale{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

//    videoComposition.customVideoCompositorClass = [FWCustomVideoCompositor class];

    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    //第一个视频时长
    AVURLAsset *asset = [_clips objectAtIndex:0];
    float duration = CMTimeGetSeconds(asset.duration);


     //拼接加速的区域
    CMTime startTime = CMTimeMakeWithSeconds(duration , 1);
    CMTime durationTime = CMTimeMakeWithSeconds(3, 1);
    CMTimeRange timeRange = CMTimeRangeMake(startTime, durationTime);

    CMTime timeAdd = kCMTimeZero;
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < clipsCount; i++) {
        AVURLAsset *asset = [_clips objectAtIndex:i];

        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);

        [videoTrack insertTimeRange:video_timeRange ofTrack:clipVideoTrack atTime:timeAdd error:nil];

//        CMTime destinationTimeRange = CMTimeMultiplyByFloat64(asset.duration, 0.3);
//        [videoTrack scaleTimeRange:video_timeRange toDuration:destinationTimeRange];

        timeAdd = CMTimeAdd(timeAdd, asset.duration);
        [videoTrack setPreferredTransform:clipVideoTrack.preferredTransform];
        if (i == clipsCount - 1) {//倒数最后一个
            CMTime destinationTimeRange = CMTimeMultiplyByFloat64(timeRange.duration, 5.0);
            [videoTrack scaleTimeRange:timeRange toDuration:destinationTimeRange];

        }


    }
     bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, timeAdd);

    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction]; //一个视频轨道
       NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
       NSInteger trackCount = 1;
       for (int i = 0; i < trackCount; ++i) {
           AVMutableVideoCompositionLayerInstruction *videoLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];//视频轨道中的一个视频
           videoLayerInstruction.trackID = i + 1;
           [layerInstructionArray addObject:videoLayerInstruction];
       }
       instruction.layerInstructions = layerInstructionArray;
       instruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
       videoComposition.instructions = @[ instruction ];

    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;
}

//普通的合并
- (void)buildCompositionObjectsMerger{
    if ( (_clips == nil) || [_clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }

    CGSize videoSize = [[_clips objectAtIndex:0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;

    composition.naturalSize = videoSize;

    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B".

    videoComposition = [AVMutableVideoComposition videoComposition];

    videoComposition.customVideoCompositorClass = [FWCustomVideoCompositor class];


    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;

    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    CMTime timeAdd = kCMTimeZero;
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    for (int i = 0; i < clipsCount; i++) {
        AVURLAsset *asset = [_clips objectAtIndex:i];

        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,asset.duration);

        [videoTrack insertTimeRange:video_timeRange ofTrack:clipVideoTrack atTime:timeAdd error:nil];
         timeAdd = CMTimeAdd(timeAdd, asset.duration);
        [videoTrack setPreferredTransform:clipVideoTrack.preferredTransform];
    }
     bgVideoTimeRange = CMTimeRangeMake(kCMTimeZero, timeAdd);

/*
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction]; //一个视频轨道
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    NSInteger trackCount = 1;
    for (int i = 0; i < trackCount; ++i) {
        AVMutableVideoCompositionLayerInstruction *videoLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];//视频轨道中的一个视频
        videoLayerInstruction.trackID = i + 1;
        [layerInstructionArray addObject:videoLayerInstruction];
    }
    instruction.layerInstructions = layerInstructionArray;
    instruction.timeRange = bgVideoTimeRange;
    videoComposition.instructions = @[ instruction ];
*/
    NSMutableArray *instructions = [NSMutableArray array];

    CustomVideoCompositionInstruction *videoInstruction = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:videoTrack.trackID]] timeRange:bgVideoTimeRange];
    AVURLAsset *asset = [_clips objectAtIndex:0];
//    durationRanges[0] = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(8, 1));
//       durationRanges[1] = CMTimeRangeMake(CMTimeMakeWithSeconds(5, 1), CMTimeMakeWithSeconds(8, 1));
    float duration = CMTimeGetSeconds(asset.duration);
    videoInstruction.filterTimeRange =  CMTimeRangeMake(CMTimeMakeWithSeconds(duration, 1), CMTimeMakeWithSeconds(2, 1));
    [instructions addObject:videoInstruction];
    videoComposition.instructions = instructions;


    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }

    self.composition = composition;
    self.videoComposition = videoComposition;
}

- (void)buildTransitionComposition:(AVMutableComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition
{
    CMTime nextClipStartTime = kCMTimeZero;
    NSInteger i;
    NSUInteger clipsCount = [_clips count];

    CMTimeRange bgVideoTimeRange = kCMTimeRangeZero;
    // BG video duration
    AVAsset *videoAsset = _clips.firstObject;

    NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = [tracks firstObject];
    bgVideoTimeRange = [videoTrack timeRange];

    float duration = CMTimeGetSeconds(bgVideoTimeRange.duration);
    NSLog(@"视频 duration：%lf",duration);

    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[2];
    AVMutableCompositionTrack *compositionAudioTracks[2];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < clipsCount; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...
        AVURLAsset *asset = [_clips objectAtIndex:i];


        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        [compositionVideoTracks[alternatingIndex] insertTimeRange:bgVideoTimeRange ofTrack:clipVideoTrack atTime:kCMTimeZero error:nil];
        [compositionVideoTracks[alternatingIndex] setPreferredTransform:clipVideoTrack.preferredTransform];

//        AVAssetTrack *clipAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
//        [compositionAudioTracks[alternatingIndex] insertTimeRange:bgVideoTimeRange ofTrack:clipAudioTrack atTime:kCMTimeZero error:nil];
    }

    // Set up the video composition to perform cross dissolve or diagonal wipe transitions between clips.
    NSMutableArray *instructions = [NSMutableArray array];

    // Cycle between "pass through A", "transition from A to B", "pass through B"
    // BG video

//    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
//
//    videoComposition.renderSize = CGSizeMake(videoSize.width, videoSize.height);
//
//    videoComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / firstVideoTrack.nominalFrameRate, firstVideoTrack.naturalTimeScale);
//    instruction.timeRange = [composition.tracks.firstObject timeRange];

//    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] initWithCapacity:1];
//
//    for (i = 0; i < clipsCount; i++ ) {
//        NSInteger alternatingIndex = i % 2; // alternating targets
//
//    }
    APLCustomVideoCompositionInstruction *videoInstruction2 = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[[NSNumber numberWithInt:compositionVideoTracks[0].trackID], [NSNumber numberWithInt:compositionVideoTracks[1].trackID]] forTimeRange:bgVideoTimeRange];
    //                newInstruction.layerInstructions = instruction.layerInstructions;
    //                [instructions addObject:videoInstruction];

    // First track -> Foreground track while compositing
    videoInstruction2.foregroundTrackID = compositionVideoTracks[0].trackID;
    // Second track -> Background track while compositing
    videoInstruction2.backgroundTrackID = compositionVideoTracks[1].trackID;

    [instructions addObject:videoInstruction2];
    videoComposition.instructions = instructions;

}



- (AVAssetExportSession*)assetExportSessionWithPreset:(NSString*)presetName
{
	AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:self.composition presetName:presetName];
	session.videoComposition = self.videoComposition;
	return session;
}

- (AVPlayerItem *)playerItem
{
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
	playerItem.videoComposition = self.videoComposition;

	return playerItem;
}

- (AVMutableComposition *)playerComposition
{

    return self.composition;
}

@end
