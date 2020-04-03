//
//  ViewController.m
//  OpenGL-渲染视频
//
//  Created by fuzhongw on 2020/3/13.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "ViewController.h"
#import "MKShortVideoCamera.h"
#import "MKGPUImageView.h"
#import "MultiVideoCamera.h"
#import "AVFoundationViewController.h"

@interface ViewController ()<MKShootRecordRenderDelegate,MMultiVideoCameraDelegate>
@property(nonatomic, strong) MKShortVideoCamera *videoCamera;

@property(nonatomic, strong) MKGPUImageView *previewView;

@property(nonatomic, strong) MultiVideoCamera *mutvideoCamera;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.


}

- (IBAction)normalRecord:(id)sender {
    [self initSession];
    [self initButton];
}


- (IBAction)doubleRecord:(id)sender {
    [self initMultiSession];
    [self initButton];
}
- (IBAction)clickAVFounationBtn:(id)sender {
    AVFoundationViewController *vc = [[AVFoundationViewController alloc] init];
       [self.navigationController pushViewController:vc animated:YES];
}


-(void)initMultiSession{
      _mutvideoCamera = [[MultiVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront size:CGSizeMake(480, 640)];
      _mutvideoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
      _mutvideoCamera.horizontallyMirrorFrontFacingCamera = YES;
      _mutvideoCamera.delegate = self;


      _previewView = [[MKGPUImageView alloc] initWithFrame:self.view.bounds];
      _previewView.fillMode = kMKGPUImageFillModePreserveAspectRatioAndFill;
      [self.view addSubview:_previewView];

      [_mutvideoCamera startSession];
}

-(void)initSession{
      _videoCamera = [[MKShortVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront size:CGSizeMake(480, 640)];
      _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
      _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
      _videoCamera.delegate = self;


      _previewView = [[MKGPUImageView alloc] initWithFrame:self.view.bounds];
      _previewView.fillMode = kMKGPUImageFillModePreserveAspectRatioAndFill;
      [self.view addSubview:_previewView];

      [_videoCamera startSession];
}


-(void)initButton{

    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:startBtn];
    startBtn.frame = CGRectMake(20, 100, 80, 44);
    [startBtn setTitle:@"开始" forState:UIControlStateNormal];
    [startBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startBtn addTarget:self action:@selector(startRecord) forControlEvents:UIControlEventTouchUpInside];
    [startBtn setBackgroundColor:[UIColor whiteColor]];

    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:stopBtn];
    stopBtn.frame = CGRectMake(200, 100, 80, 44);
    [stopBtn setTitle:@"结束" forState:UIControlStateNormal];
    [stopBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [stopBtn addTarget:self action:@selector(stopRecord) forControlEvents:UIControlEventTouchUpInside];
    [stopBtn setBackgroundColor:[UIColor whiteColor]];

}

#pragma mark-
#pragma mark MKShootRecordRenderDelegate

- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation
{
    NSLog(@"renderTexture");

    [_previewView renderTexture:inputTextureId inputSize:newSize rotateMode:rotation];
}

- (void)didWriteMovieAtURL:(NSURL * _Nullable)outputURL {
    NSLog(@"didWriteMovieAtURL");
}


- (void)effectsProcessingTexture:(GLuint)texture inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation {
        NSLog(@"effectsProcessingTexture");

}

#pragma mark -
#pragma mark MKOverlayViewDelegate
- (void)startRecord
{
    if (self.videoCamera) {

        [_videoCamera startWriting];
    }

    if (self.mutvideoCamera) {

        [self.mutvideoCamera startWriting];
    }
    NSLog(@"开始录制 -- 保存");
}

- (void)stopRecord
{
    if (self.videoCamera) {

        [_videoCamera stopWriting];
    }

    if (self.mutvideoCamera) {

        [self.mutvideoCamera stopWriting];
    }

    NSLog(@"停止录制-- 保存");
}

@end
