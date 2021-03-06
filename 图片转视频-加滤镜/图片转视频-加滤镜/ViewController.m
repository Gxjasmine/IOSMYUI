//
//  ViewController.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "ViewController.h"
#import "AudioToVideo.h"
#import "VideoViewController.h"
#import "EffectsViewController.h"
#import "TestViewController.h"
#import "MFShaderHelper.h"
@interface ViewController ()
@property(nonatomic,strong)AudioToVideo *builder;

@end
#warning 视频和相关资源归出处所有，不得用于商业活动，后果自负
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.builder= [[AudioToVideo alloc] init];

}
- (IBAction)onclickMerger:(id)sender {
    [self.builder testCompressionSession];
}

- (IBAction)onclickPlay:(id)sender {
    VideoViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"VideoViewController"];
    vc.theVideoPath = self.builder.theVideoPath;
    [self.navigationController pushViewController:vc animated:true];

    
}

- (IBAction)onclickEffectButton:(id)sender {
    EffectsViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"EffectsViewController"];
      [self.navigationController pushViewController:vc animated:true];
}

- (IBAction)onclIcktest:(id)sender {

    TestViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"TestViewController"];
         [self.navigationController pushViewController:vc animated:true];
}


@end
