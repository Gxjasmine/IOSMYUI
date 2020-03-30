//
//  SourceEAGLContext.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "SourceEAGLContext.h"
#import <UIKit/UIKit.h>

@interface SourceEAGLContext()

@end

@implementation SourceEAGLContext

static void *openGLESContextQueueKey;

static SourceEAGLContext *_onetimeClass;
+ (SourceEAGLContext *)sharedInstance {
static dispatch_once_t oneToken;

    dispatch_once(&oneToken, ^{

        _onetimeClass = [[SourceEAGLContext alloc]init];

    });
    return _onetimeClass;
}

-(instancetype)init
{
    self = [super init];
    if(self) {
        _currentContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_currentContext) {
            NSLog(@"初始化上下文失败");
            return nil;
        }

        _currentContext2 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
           if (!_currentContext2) {
               NSLog(@"初始化上下文失败");
               return nil;
           }

        [EAGLContext setCurrentContext:_currentContext];
        //        [self setupOffscreenRenderContext];
        //        [self loadShaders];
        [EAGLContext setCurrentContext:nil];
        openGLESContextQueueKey = &openGLESContextQueueKey;
        
        _contextQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.openGLESContextQueue", NULL);
        
#if OS_OBJECT_USE_OBJC
        dispatch_queue_set_specific(_contextQueue, openGLESContextQueueKey, (__bridge void *)self, NULL);
#endif
    }

    return self;
}

+ (void *)contextKey {
    return openGLESContextQueueKey;
}

+ (dispatch_queue_t)sharedContextQueue
{
    return [[self sharedInstance] contextQueue];
}

+ (void)useImageProcessingContext
{
    [[self sharedInstance] useAsCurrentContext];
}

- (void)useAsCurrentContext
{

    EAGLContext *imageProcessingContext = [self currentContext];
    if ([EAGLContext currentContext] != imageProcessingContext)
    {
        [EAGLContext setCurrentContext:imageProcessingContext];
    }
}

@end
