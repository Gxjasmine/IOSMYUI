//
//  EffectsViewController.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/31.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "EffectsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>

#import "APLSimpleEditor.h"

#define WWScreamW [UIScreen mainScreen].bounds.size.width
#define WWScreamH [UIScreen mainScreen].bounds.size.height

@interface EffectsViewController ()
@property (nonatomic, strong) APLSimpleEditor        *editor;
@property (nonatomic, strong) NSMutableArray * clips;
@property (nonatomic, strong) NSMutableArray * clipTimeRanges;


@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@property (nonatomic, assign) long tag;
@end

@implementation EffectsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.editor = [[APLSimpleEditor alloc] init];
    self.clips = [[NSMutableArray alloc] initWithCapacity:2];
    self.clipTimeRanges = [[NSMutableArray alloc] initWithCapacity:2];
}

- (IBAction)onclickButton:(UIButton *)sender {
    NSLog(@"sender tag:%ld",(long)sender.tag);
    self.tag = sender.tag;
    [self.clips removeAllObjects];
    [self.clipTimeRanges removeAllObjects];
    switch (sender.tag) {
        case 0:
            [self test00];
            break;
        case 1:
            [self test01];
            break;
        case 2:
            [self test02];
            break;
        case 3:
            [self test03];
            break;
        case 4:
            [self test04];
            break;
        case 5:
            [self test05];
            break;
        case 6:
            [self test06];
            break;
        case 7:
            [self test07];
            break;
        default:
            break;
    }
}



//视频融合
-(void)test00{
    [self setupEditingAndPlayback];
}
//视频添加灵魂出窍
-(void)test01{
    [self setupEditingAndPlayback1];

}
//视频融合，慢放和灵魂出窍
-(void)test02{
    [self setupEditingAndPlayback2];

}

-(void)test03{
  [self setupEditingAndPlayback4];
}

-(void)test04{
    [self setupEditingAndPlayback5];

}

-(void)test05{
    NSLog(@"test05");

}

-(void)test06{
    NSLog(@"test06");

}

-(void)test07{
    NSLog(@"test07");

}

#pragma mark - Simple Editor
- (void)setupEditingAndPlayback5
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mov"]]];

      [self.clips addObject:asset1];

     [self synchronizeWithEditor];

}



- (void)setupEditingAndPlayback4
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"M4V"]]];

      [self.clips addObject:asset1];

     [self synchronizeWithEditor];

}

- (void)setupEditingAndPlayback3
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample1" ofType:@"MP4"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample2" ofType:@"MP4"]]];

      [self.clips addObject:asset1];
      [self.clips addObject:asset2];

     [self synchronizeWithEditor];

}

- (void)setupEditingAndPlayback2
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample1" ofType:@"MP4"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample2" ofType:@"MP4"]]];

      [self.clips addObject:asset1];
      [self.clips addObject:asset2];

     [self synchronizeWithEditor];

}


- (void)setupEditingAndPlayback1
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample1" ofType:@"MP4"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample2" ofType:@"MP4"]]];

      [self.clips addObject:asset1];
      [self.clips addObject:asset2];

     [self synchronizeWithEditor];

}

- (void)setupEditingAndPlayback
{
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"ping20s" ofType:@"mp4"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"透明1" ofType:@"mp4"]]];

    dispatch_group_t dispatchGroup = dispatch_group_create();
    NSArray *assetKeysToLoadAndTest = @[@"tracks", @"duration", @"composable"];

    [self loadAsset:asset1 withKeys:assetKeysToLoadAndTest usingDispatchGroup:dispatchGroup];
    [self loadAsset:asset2 withKeys:assetKeysToLoadAndTest usingDispatchGroup:dispatchGroup];

    // Wait until both assets are loaded
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^(){
        [self synchronizeWithEditor];
    });
}

- (void)synchronizeWithEditor
{
    // Clips
    NSMutableArray *validClips = [NSMutableArray arrayWithCapacity:2];
    for (AVURLAsset *asset in self.clips) {
        if (![asset isKindOfClass:[NSNull class]]) {
            [validClips addObject:asset];
        }
    }
    self.editor.clips = validClips;

    NSMutableArray *validClipTimeRanges = [NSMutableArray arrayWithCapacity:2];
    for (NSValue *timeRange in self.clipTimeRanges) {
        if (! [timeRange isKindOfClass:[NSNull class]]) {
            [validClipTimeRanges addObject:timeRange];
        }
    }

    self.editor.clipTimeRanges = validClipTimeRanges;

    // Transitions
    self.editor.transitionDuration = kCMTimeInvalid;


    // Build AVComposition and AVVideoComposition objects for playback
    if (self.tag == 0) {
        [self.editor buildCompositionObjectsForPlayback:YES];

    }else if (self.tag == 1){
        [self.editor buildCompositionObjectsMerger];

    }else if (self.tag == 2){
        [self.editor buildCompositionObjectsScale];

    }else if (self.tag == 3){
        [self.editor buildCompositionObjectsModel01];

    }else if (self.tag == 4){
        [self.editor buildCompositionObjectsModel02];

    }

    [self synchronizePlayerWithEditor];
}

- (void)synchronizePlayerWithEditor
{
    if (self.player == nil)
    {
        self.player = [[AVPlayer alloc] init];

    }

    AVPlayerItem *playerItem = [self.editor playerItem];

    if (self.playerItem != playerItem) {


        self.playerItem = playerItem;

        if ( self.playerItem ) {
            if ( [self.playerItem respondsToSelector:@selector(setSeekingWaitsForVideoCompositionRendering:)] )
                self.playerItem.seekingWaitsForVideoCompositionRendering = YES;

            // Observe the player item "status" key to determine when it is ready to play

        }
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }


    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player ];

    playerLayer.frame = CGRectMake(0, WWScreamH * 0.25, WWScreamW, WWScreamH * 0.65);

    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

    [self.view.layer addSublayer:playerLayer];

    [self.player  play];


}

- (void)loadAsset:(AVAsset *)asset withKeys:(NSArray *)assetKeysToLoad usingDispatchGroup:(dispatch_group_t)dispatchGroup
{
    dispatch_group_enter(dispatchGroup);
    [asset loadValuesAsynchronouslyForKeys:assetKeysToLoad completionHandler:^(){
        // First test whether the values of each of the keys we need have been successfully loaded.
        for (NSString *key in assetKeysToLoad) {
            NSError *error;

            if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed) {
                NSLog(@"Key value loading failed for key:%@ with error: %@", key, error);
                goto bail;
            }
        }
        if (![asset isComposable]) {
            NSLog(@"Asset is not composable");
            goto bail;
        }

        [self.clips addObject:asset];
        [self.clipTimeRanges addObject:[NSValue valueWithCMTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(5, 1))]];

bail:
        dispatch_group_leave(dispatchGroup);
    }];
}

-(void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    NSLog(@"didReceiveMemoryWarning");
}
@end
