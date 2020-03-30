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

@interface ViewController ()
@property(nonatomic,strong)AudioToVideo *builder;

@end

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



@end
