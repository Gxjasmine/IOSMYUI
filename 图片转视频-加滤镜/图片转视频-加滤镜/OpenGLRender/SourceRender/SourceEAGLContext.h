//
//  SourceEAGLContext.h
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

//#import <Foundation/Foundation.h>
#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface SourceEAGLContext : NSObject

@property(readonly, retain, nonatomic) EAGLContext *currentContext;
@property(readonly, retain, nonatomic) EAGLContext *currentContext2;

@property(readonly, nonatomic) dispatch_queue_t contextQueue;

+ (SourceEAGLContext *)sharedInstance;
+ (void *)contextKey;
+ (dispatch_queue_t)sharedContextQueue;
+ (void)useImageProcessingContext;


@end

NS_ASSUME_NONNULL_END
