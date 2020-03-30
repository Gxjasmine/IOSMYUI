//
//  ScaleFilter.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CustonFilter.h"
NS_ASSUME_NONNULL_BEGIN

@interface ScaleFilter : CustonFilter

-(void)stopFilerAnimation;
- (void)startFilerAnimation;
- (float)getTimestamp;
@end

NS_ASSUME_NONNULL_END
