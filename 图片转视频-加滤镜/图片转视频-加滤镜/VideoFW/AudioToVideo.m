//
//  AudioToVideo.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/27.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "AudioToVideo.h"
#import <AVKit/AVKit.h>

@interface AudioToVideo () {

    NSMutableArray*imageArr;    //未压缩的图片
    NSMutableArray*imageArray;  //经过压缩的图片
}
@end

@implementation AudioToVideo

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupInit];
    }
    return self;
}

- (void)setupInit {

    imageArray = [[NSMutableArray alloc]init];
    imageArr = [[NSMutableArray alloc]init];

    NSString *name = @"";
    UIImage *img = nil;

    for (int i = 1; i < 6; i++) {
        name = [NSString stringWithFormat:@"%d",i];
        img = [UIImage imageNamed:name];
        [imageArr addObject:img];
    }

    for (int i = 0; i < imageArr.count; i++) {

        UIImage *imageNew = imageArr[i];

        //设置image的尺寸
        CGSize imgeSize = CGSizeMake(320, 480);

        //对图片大小进行压缩--
        imageNew = [self imageWithImage:imageNew scaledToSize:imgeSize];

        [imageArray addObject:imageNew];
    }

}

//对图片尺寸进行压缩--
-(UIImage*)imageWithImage:(UIImage*)image scaledToSize:(CGSize)newSize

{
    //    新创建的位图上下文 newSize为其大小
    UIGraphicsBeginImageContext(newSize);
    //    对图片进行尺寸的改变
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];

    //    从当前上下文中获取一个UIImage对象  即获取新的图片对象
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return newImage;

}

#pragma mark- 按钮点击操作

//视频合成按钮点击操作
- (void)testCompressionSession {

    //设置mov路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);

    NSString *moviePath = [[paths objectAtIndex:0]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",@"test"]];
    NSLog(@"路径 --：%@",moviePath);
    self.theVideoPath=moviePath;
    if ([[NSFileManager defaultManager] fileExistsAtPath:moviePath])
       {
           [[NSFileManager defaultManager] removeItemAtPath:moviePath error:nil];
       }
    //定义视频的大小320 480 倍数
    CGSize size = CGSizeMake(320,480);

    NSError *error = nil;

    //    转成UTF-8编码
    unlink([moviePath UTF8String]);

    NSLog(@"path->%@",moviePath);

    //     iphone提供了AVFoundation库来方便的操作多媒体设备，AVAssetWriter这个类可以方便的将图像和音频写成一个完整的视频文件

    AVAssetWriter *videoWriter = [[AVAssetWriter alloc]initWithURL:[NSURL fileURLWithPath:moviePath]fileType:AVFileTypeMPEG4 error:&error];

    NSParameterAssert(videoWriter);

    if(error) {
        NSLog(@"error =%@",[error localizedDescription]);
        return;
    }

    //mov的格式设置 编码格式 宽度 高度 AVVideoCodecH264  AVVideoCodecTypeH264
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264,AVVideoCodecKey,

                                     [NSNumber numberWithInt:size.width],AVVideoWidthKey,

                                     [NSNumber numberWithInt:size.height],AVVideoHeightKey,nil];

    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];

    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],kCVPixelBufferPixelFormatTypeKey,nil];

    //    AVAssetWriterInputPixelBufferAdaptor提供CVPixelBufferPool实例,
    //    可以使用分配像素缓冲区写入输出文件。使用提供的像素为缓冲池分配通常
    //    是更有效的比添加像素缓冲区分配使用一个单独的池
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];

    NSParameterAssert(writerInput);

    NSParameterAssert([videoWriter canAddInput:writerInput]);

    if([videoWriter canAddInput:writerInput]){

        NSLog(@"11111");

    }else{

        NSLog(@"22222");

    }

    [videoWriter addInput:writerInput];

    [videoWriter startWriting];

    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    //合成多张图片为一个视频文件

    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue",NULL);

    int __block frame = -1;

    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{

        while([writerInput isReadyForMoreMediaData]) {

            if(++frame >= [self->imageArray count] * 5) {
                [writerInput markAsFinished];

                [videoWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"完成");

                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

                        NSLog(@"图片--->视频合成完毕");

                    }];

                }];
                break;
            }

            CVPixelBufferRef buffer = NULL;

            int idx = frame / 5;

            NSLog(@"idx==%d",idx);
            NSString *progress = [NSString stringWithFormat:@"%0.2lu",idx / [self->imageArr count]];

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{

                NSLog(@"合成进度:%@",progress);

            }];


            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[self->imageArray objectAtIndex:idx]CGImage]size:size];

            if(buffer){

                //设置每秒钟播放图片的个数
                //CMTimeMake(a,b) a当前第几帧, b每秒钟多少帧.当前播放时间a/b

                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,1)]) {

                    NSLog(@"FAIL");

                } else {

                    NSLog(@"OK");
                }

                CFRelease(buffer);
            }
        }
    }];


}

- (void)testCompressionSession2 {

    //设置mov路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);

    NSString *moviePath = [[paths objectAtIndex:0]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov",@"test"]];
    NSLog(@"路径 --：%@",moviePath);
    self.theVideoPath=moviePath;

    //定义视频的大小320 480 倍数
    CGSize size = CGSizeMake(320,480);

    NSError *error = nil;

    //    转成UTF-8编码
    unlink([moviePath UTF8String]);

    NSLog(@"path->%@",moviePath);

    //     iphone提供了AVFoundation库来方便的操作多媒体设备，AVAssetWriter这个类可以方便的将图像和音频写成一个完整的视频文件

    AVAssetWriter *videoWriter = [[AVAssetWriter alloc]initWithURL:[NSURL fileURLWithPath:moviePath]fileType:AVFileTypeQuickTimeMovie error:&error];

    NSParameterAssert(videoWriter);

    if(error) {
        NSLog(@"error =%@",[error localizedDescription]);
        return;
    }

    //mov的格式设置 编码格式 宽度 高度 AVVideoCodecH264  AVVideoCodecTypeH264
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264,AVVideoCodecKey,

                                     [NSNumber numberWithInt:size.width],AVVideoWidthKey,

                                     [NSNumber numberWithInt:size.height],AVVideoHeightKey,nil];

    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];

    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],kCVPixelBufferPixelFormatTypeKey,nil];

    //    AVAssetWriterInputPixelBufferAdaptor提供CVPixelBufferPool实例,
    //    可以使用分配像素缓冲区写入输出文件。使用提供的像素为缓冲池分配通常
    //    是更有效的比添加像素缓冲区分配使用一个单独的池
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];

    NSParameterAssert(writerInput);

    NSParameterAssert([videoWriter canAddInput:writerInput]);

    if([videoWriter canAddInput:writerInput]){

        NSLog(@"11111");

    }else{

        NSLog(@"22222");

    }

    [videoWriter addInput:writerInput];

    [videoWriter startWriting];

    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    //合成多张图片为一个视频文件

    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue",NULL);

    int __block frame = -1;

    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{

        while([writerInput isReadyForMoreMediaData]) {

            if(++frame >= [self->imageArray count] * 10) {
                [writerInput markAsFinished];

                [videoWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"完成");

                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

                        NSLog(@"图片--->视频合成完毕");

                    }];

                }];
                break;
            }

            CVPixelBufferRef buffer = NULL;

            int idx = frame / 10;

            NSLog(@"idx==%d",idx);
            NSString *progress = [NSString stringWithFormat:@"%0.2lu",idx / [self->imageArr count]];

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{

                NSLog(@"合成进度:%@",progress);

            }];


            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[self->imageArray objectAtIndex:idx]CGImage]size:size];

            if(buffer){

                //设置每秒钟播放图片的个数
                //CMTimeMake(a,b) a当前第几帧, b每秒钟多少帧.当前播放时间a/b

                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,10)]) {

                    NSLog(@"FAIL");

                } else {

                    NSLog(@"OK");
                }

                CFRelease(buffer);
            }
        }
    }];


}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size {

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:

                           [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,

                           [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];

    CVPixelBufferRef pxbuffer = NULL;

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef) options,&pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer,0);

    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    NSParameterAssert(pxdata !=NULL);

    CGColorSpaceRef rgbColorSpace=CGColorSpaceCreateDeviceRGB();

    //    当你调用这个函数的时候，Quartz创建一个位图绘制环境，也就是位图上下文。当你向上下文中绘制信息时，Quartz把你要绘制的信息作为位图数据绘制到指定的内存块。一个新的位图上下文的像素格式由三个参数决定：每个组件的位数，颜色空间，alpha选项

//    CGContextRef context = CGBitmapContextCreate(pxdata,size.width,size.height,8,4*size.width,rgbColorSpace,kCGImageAlphaPremultipliedFirst);
    CGContextRef context = CGBitmapContextCreate(pxdata,size.width,size.height,8, CVPixelBufferGetBytesPerRow(pxbuffer),rgbColorSpace,kCGImageAlphaPremultipliedFirst);

    NSParameterAssert(context);

    //使用CGContextDrawImage绘制图片  这里设置不正确的话 会导致视频颠倒

    //    当通过CGContextDrawImage绘制图片到一个context中时，如果传入的是UIImage的CGImageRef，因为UIKit和CG坐标系y轴相反，所以图片绘制将会上下颠倒

    CGContextDrawImage(context,CGRectMake(0,0,CGImageGetWidth(image),CGImageGetHeight(image)), image);

    // 释放色彩空间

    CGColorSpaceRelease(rgbColorSpace);

    // 释放context

    CGContextRelease(context);

    // 解锁pixel buffer

    CVPixelBufferUnlockBaseAddress(pxbuffer,0);

    return pxbuffer;

}

@end
