//
//  VideoViewController.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "VideoViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
//转场
#import "APLCustomVideoCompositor.h"
#import "APLCustomVideoCompositionInstruction.h"

//原视频
#import "FWCustomVideoCompositor.h"
#import "CustomVideoCompositionInstruction.h"


#define WWScreamW [UIScreen mainScreen].bounds.size.width
#define WWScreamH [UIScreen mainScreen].bounds.size.height
@interface VideoViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@property (nonatomic, assign) BOOL isExporting;
@property (nonatomic, strong) NSString *exportPath;


@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor= [UIColor whiteColor];
}
- (IBAction)onclickButton:(UIButton *)sender {
    if (sender.tag == 0) {

        [self playAction];
    }
}

- (IBAction)pausePaly:(id)sender {
}

- (IBAction)onclickSave:(id)sender {
    [self exportAction];
}


//视频播放按钮点击操作
- (void)playAction {

    // 文件管理器
    NSFileManager *fileManager = [[NSFileManager alloc]init];

    if (![fileManager fileExistsAtPath:self.theVideoPath]) {
        NSLog(@"文件不存在");
        return;
    }

    NSURL *sourceMovieURL = [NSURL fileURLWithPath:self.theVideoPath];

    self.asset = [AVURLAsset URLAssetWithURL:sourceMovieURL options:nil];

    self.playerItem = [AVPlayerItem playerItemWithAsset:self.asset];

    self.videoComposition = [self createVideoCompositionWithAsset:self.asset];
    self.videoComposition.customVideoCompositorClass = [FWCustomVideoCompositor class];
    self.playerItem.videoComposition = self.videoComposition;

    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];

    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player ];

    playerLayer.frame = CGRectMake(0, WWScreamH * 0.25, WWScreamW, WWScreamH * 0.65);

    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

    [self.view.layer addSublayer:playerLayer];

    [self.player  play];


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
//        CustomVideoCompositionInstruction *newInstruction = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:trackIDs forTimeRange:instruction.timeRange];

        CustomVideoCompositionInstruction *newInstruction = [[CustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:trackIDs timeRange:instruction.timeRange];
        newInstruction.layerInstructions = instruction.layerInstructions;
        [newInstructions addObject:newInstruction];
    }

    videoComposition.instructions = newInstructions;
//    videoComposition.renderScale
//    videoComposition.frameDuration = CMTimeMake(1, 30);//
//     CMTime frame = videoComposition.frameDuration;
    return videoComposition;
}

#pragma mark - Private

- (void)exportAction {

    // 文件管理器
    NSFileManager *fileManager = [[NSFileManager alloc]init];

    if (![fileManager fileExistsAtPath:self.theVideoPath]) {
        NSLog(@"文件不存在");
        return;
    }

    NSURL *sourceMovieURL = [NSURL fileURLWithPath:self.theVideoPath];

    self.asset = [AVURLAsset URLAssetWithURL:sourceMovieURL options:nil];

    if (self.isExporting) {
        return;
    }
    self.isExporting = YES;

    // 先暂停播放
    [self.player pause];

    if (self.videoComposition == nil) {
        self.videoComposition = [self createVideoCompositionWithAsset:self.asset];
          self.videoComposition.customVideoCompositorClass = [FWCustomVideoCompositor class];
    }

    // 创建导出任务
    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:self.asset presetName:AVAssetExportPresetHighestQuality];
    self.exportSession.videoComposition = self.videoComposition;
    self.exportSession.outputFileType = AVFileTypeMPEG4;

    NSString *fileName = [NSString stringWithFormat:@"export.m4v"];
    self.exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

     if ([[NSFileManager defaultManager]fileExistsAtPath:self.exportPath]) {
           [[NSFileManager defaultManager]removeItemAtPath:self.exportPath error:nil];
       }

    self.exportSession.outputURL = [NSURL fileURLWithPath:self.exportPath];

    __weak typeof(self) weakself = self;
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        NSLog(@"导出成功");
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

//    self.exportSession.progress;
}

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
