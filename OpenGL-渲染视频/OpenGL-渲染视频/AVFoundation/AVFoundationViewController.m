//
//  AVFoundationViewController.m
//  testVideoFilter
//
//  Created by Lyman Li on 2020/3/8.
//  Copyright © 2020 Lyman Li. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

#import "CustomVideoCompositing.h"
#import "CustomVideoCompositionInstruction.h"
#import "AVFoundationViewController.h"

@interface AVFoundationViewController ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@property (nonatomic, strong) NSString *exportPath;

@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *exportButton;

@property (nonatomic, assign) BOOL isExporting;

@end

@implementation AVFoundationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self commonInit];
}

#pragma mark - Private

- (void)commonInit {
    [self setupUI];
    [self setupPlayer];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupPlayButton];
    [self setupExportButton];
}

- (void)setupPlayButton {
    self.playButton = [[UIButton alloc] init];
    [self.view addSubview:self.playButton];
    [self.playButton setFrame:CGRectMake(20, self.view.frame.size.width + 150, 120, 60)];
    [self configButton:self.playButton];
    [self.playButton setTitle:@"播放" forState:UIControlStateNormal];
    [self.playButton setTitle:@"暂停" forState:UIControlStateSelected];
    [self.playButton addTarget:self
                        action:@selector(playAction:)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupExportButton {
    self.exportButton = [[UIButton alloc] init];
    [self.view addSubview:self.exportButton];

    [self.exportButton setFrame:CGRectMake(150, self.view.frame.size.width + 150, 120, 60)];

    [self configButton:self.exportButton];
    [self.exportButton setTitle:@"导出" forState:UIControlStateNormal];
    [self.exportButton addTarget:self
                          action:@selector(exportAction:)
                forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupPlayer {
    // asset
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"中国风雪景桃花舞台背景视频" withExtension:@"mp4"];
    self.asset = [AVURLAsset assetWithURL:url];

     NSArray *tracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
       AVAssetTrack *firstVideoTrack = [tracks firstObject];

    float nominalFrameRate = firstVideoTrack.nominalFrameRate;

    float naturalTimeScale = firstVideoTrack.naturalTimeScale;


    CMTime T1 = CMTimeMakeWithSeconds(1.0 / firstVideoTrack.nominalFrameRate, firstVideoTrack.naturalTimeScale);

     CMTime duration = self.asset.duration;
    /*


                CMTimeMake(a,b) a当前第几帧, b:每秒钟多少帧
                CMTimeMakeWithSeconds(a,b) a当前时间,b: 每秒钟多少帧



     (CMTime) duration = 59490 1000ths of a second {
       value = 59490
       timescale = 1000
       flags = kCMTimeFlags_Valid
       epoch = 0
     }
     CMTime frame = videoComposition.frameDuration;
     (CMTime) frame = 3003 90000ths of a second {
       value = 3003
       timescale = 90000
       flags = 3
       epoch = 0
     }
     帧率：timescale / value = 90000 / 3003 = 29.97
     1781 : 1781 / 29.97 = 59.42
     */

    // videoComposition
    self.videoComposition = [self createVideoCompositionWithAsset:self.asset];
    self.videoComposition.customVideoCompositorClass = [CustomVideoCompositing class];

    Float64  DDD =CMTimeGetSeconds(duration); //54.49
    Float64  DDD2 =CMTimeGetSeconds(self.videoComposition.frameDuration); //54.49

    // playerItem
    self.playerItem = [[AVPlayerItem alloc] initWithAsset:self.asset];
    self.playerItem.videoComposition = self.videoComposition;
    
    // player
    self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
    
    // playerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0,
                                        80,
                                        self.view.frame.size.width,
                                        self.view.frame.size.width);
    [self.view.layer addSublayer:self.playerLayer];
}

- (AVMutableVideoComposition *)createVideoCompositionWithAsset:(AVAsset *)asset {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    NSArray *instructions = videoComposition.instructions;
    NSMutableArray *newInstructions = [NSMutableArray array];
    for (AVVideoCompositionInstruction *instruction in instructions) {
        NSArray *layerInstructions = instruction.layerInstructions;
        // TrackIDs
        NSMutableArray *trackIDs = [NSMutableArray array];
        for (AVVideoCompositionLayerInstruction *layerInstruction in layerInstructions) {
            [trackIDs addObject:@(layerInstruction.trackID)];
        }
        CustomVideoCompositionInstruction *newInstruction = [[CustomVideoCompositionInstruction alloc] initWithSourceTrackIDs:trackIDs timeRange:instruction.timeRange];
        newInstruction.layerInstructions = instruction.layerInstructions;
        [newInstructions addObject:newInstruction];
    }
    videoComposition.instructions = newInstructions;
//    videoComposition.renderScale
//    videoComposition.frameDuration = CMTimeMake(1, 30);//
//     CMTime frame = videoComposition.frameDuration;
    return videoComposition;
}

- (void)configButton:(UIButton *)button {
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.tintColor = [UIColor clearColor];
    [button.titleLabel setFont:[UIFont systemFontOfSize:14]];
    [button setBackgroundColor:[UIColor blackColor]];
    button.layer.cornerRadius = 5;
    button.layer.masksToBounds = YES;
}

#pragma mark - Action

- (void)playAction:(UIButton *)button {
    if (self.isExporting) {
        return;
    }
    
    button.selected = !button.selected;
    if (button.selected) {
        [self.player play];
    } else {
        [self.player pause];
    }
}

- (void)exportAction:(UIButton *)button {
    if (self.isExporting) {
        return;
    }
    self.isExporting = YES;
    
    // 先暂停播放
    [self.player pause];
    self.playButton.selected = NO;

    // 创建导出任务
    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:self.asset presetName:AVAssetExportPresetHighestQuality];
    self.exportSession.videoComposition = self.videoComposition;
    self.exportSession.outputFileType = AVFileTypeMPEG4;
    
    NSString *fileName = [NSString stringWithFormat:@"%f.m4v", [[NSDate date] timeIntervalSince1970] * 1000];
    self.exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    self.exportSession.outputURL = [NSURL fileURLWithPath:self.exportPath];
    
    __weak typeof(self) weakself = self;
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        [weakself saveVideo:weakself.exportPath completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{

                if (success) {
                    NSLog(@"保存成功");
                } else {
                    NSLog(@"保存失败");

                }
                weakself.isExporting = NO;
            });
        }];
    }];
}

#pragma mark - Private

// 保存视频到相册
- (void)saveVideo:(NSString *)path completion:(void (^)(BOOL success))completion {
    void (^saveBlock)(void) = ^ {
        NSURL *url = [NSURL fileURLWithPath:path];
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (completion) {
                completion(success);
            }
        }];
    };
    
    PHAuthorizationStatus authStatus = [PHPhotoLibrary authorizationStatus];
    if (authStatus == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                saveBlock();
            } else {
                if (completion) {
                    completion(NO);
                }
            }
        }];
    } else if (authStatus != PHAuthorizationStatusAuthorized) {
        if (completion) {
            completion(NO);
        }
    } else {
        saveBlock();
    }
}

@end
