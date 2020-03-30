//
//  AudioToVideo.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface AudioToVideo : NSObject
//视频地址
@property(nonatomic,strong)NSString*theVideoPath;

- (void)testCompressionSession;
@end

NS_ASSUME_NONNULL_END
