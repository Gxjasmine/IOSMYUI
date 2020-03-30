
#import "VideoBuilder.h"

typedef void(^successBlock)(void);
typedef void(^failBlock)(NSError *error);
typedef void(^exportAsynchronouslyWithCompletionHandler)(void);
typedef void(^convertToMp4Completed)(void);

@interface VideoBuilder ()

@property (nonatomic, strong) AVAssetWriter *videoWriter;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;

@property (nonatomic, assign) NSInteger frameNumber;

@property (nonatomic, assign) CGSize    videoSize;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) int32_t timeScale;
@property (nonatomic, strong) NSString *audioFile;
@end

@implementation VideoBuilder

- (void)maskFinishWithSuccess:(successBlock)success Fail:(failBlock)fail {
    
    [self.writerInput markAsFinished];
    
    [self.videoWriter finishWritingWithCompletionHandler:^{
        if (self.videoWriter.status != AVAssetReaderStatusFailed && self.videoWriter.status == AVAssetWriterStatusCompleted) {
            
            if (success) {
                success();
            }
            
        } else {
            if (fail) {
                fail(_videoWriter.error);
            }
            
            NSLog(@"create video failed, %@",self.videoWriter.error);
        }
    }];
    
    CVPixelBufferPoolRelease(self.adaptor.pixelBufferPool);
}

//初始化写入流 AVAssetWriter
- (void)initWriter{

    //设置mov路径
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
     NSString *videoOutputPath = [[paths objectAtIndex:0]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov",@"test"]];

    _videoSize = CGSizeMake(160, 90);
    _videoPath = videoOutputPath;
    _timeScale = 1;
    
    NSError *fileError;
    if ([[NSFileManager defaultManager] removeItemAtPath:self.videoPath error:&fileError]) {
    }
    NSError *error = nil;
    //告诉AVAssetWriter 文件保存路径、文件type
    self.videoWriter = [[AVAssetWriter alloc]initWithURL:[NSURL fileURLWithPath:_videoPath]
                                                fileType:AVFileTypeQuickTimeMovie
                                                   error:&error];
    
    NSParameterAssert(self.videoWriter);
    //视频的基本设置，编码格式、宽、高
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264,AVVideoCodecKey,
                                   [NSNumber numberWithInt:_videoSize.width],AVVideoWidthKey,
                                   [NSNumber numberWithInt:_videoSize.height],AVVideoHeightKey,
                                   nil];
    //根据定义好的视频格式定义输入流
    self.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:videoSettings];
    // expectsMediaDataInRealTime设置为YES, 表示实时获取摄像头和麦克风采集到的视频数据和音频数据
    self.writerInput.expectsMediaDataInRealTime = YES;
    //AVAssetWriterInputPixelBufferAdaptor负责将图片转成的缓存数据CVPixelBufferRef追加到AVAssetWriterInput中。
    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor
                    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.writerInput
                    sourcePixelBufferAttributes:nil];
    
    NSParameterAssert(self.writerInput);
    NSParameterAssert([self.videoWriter canAddInput:self.writerInput]);
    
    [self.videoWriter addInput:self.writerInput];
    
    [self.videoWriter startWriting];
    
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
}

//将图片合成为视频
- (void)convertVideoWithImageArray:(NSArray *)images Success:(successBlock)success Fail:(failBlock)fail {
    
    [self initWriter];
    // GCD 异步
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        //获取音频的时长
//        AVURLAsset* audioAsse = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:self.audioFile] options:nil];
//        CMTime cmtime = audioAsse.duration;
//        NSUInteger dTotalSeconds = CMTimeGetSeconds(cmtime);
//
//        double numberOfSecondsPerFrame = dTotalSeconds/[images count];
//        if (numberOfSecondsPerFrame == 0) {
//            numberOfSecondsPerFrame = 1;
//        }
        double frameDuration = self.timeScale * 100;

        int i;
        CVPixelBufferRef buffer = NULL;
        for ( i = 0; i < [images count];) {
            if (self.writerInput.readyForMoreMediaData) {
                //CMTimeMake(a,b) a当前第几帧, b每秒钟多少帧.当前播放时间a/b
                CMTime frameTime = CMTimeMake(1,self.timeScale);
                
                CMTime lastTime = CMTimeMake(i*frameDuration,self.timeScale);
                
                CMTime presentTime = CMTimeAdd(lastTime, frameTime);
                
                if (i == 0) {
                    presentTime = CMTimeMake(0,self.timeScale);
                }
                
                buffer = [self pixelBufferFromCGImage:[images[i] CGImage]];
                
                if (buffer) {
                    //添加视频流
                    if ([self.adaptor appendPixelBuffer:buffer withPresentationTime:lastTime]) {
                        i++;
                    }else{
                        [self maskFinishWithSuccess:success Fail:fail];
                        break;
                    }
                    
                    CVPixelBufferRelease(buffer);
                }
            }
        }
        
        if (i == images.count) {
            [self maskFinishWithSuccess:success Fail:fail];
        }
    });
}

// 将声音添加到视频里面
- (void)addAudioToVideoAudioPath:(NSString *)audioPath Completion:(exportAsynchronouslyWithCompletionHandler)completion {
    //初始化audioAsset
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
    //初始化videoAsset
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:self.videoPath] options:nil];
    //初始化合成类
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    //初始化设置轨道type为AVMediaTypeAudio
    AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //根据音频时常添加到设置里面
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    //初始化设置轨道type为VideoTrack
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    //设置视频时长等
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    //初始化导出类
    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    //导出路径
    NSString *exportPath = self.videoPath;
    NSURL *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:exportPath error:nil];
    }
    
    assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    assetExport.outputURL = exportUrl;
    assetExport.shouldOptimizeForNetworkUse = YES;
    //导出
    [assetExport exportAsynchronouslyWithCompletionHandler:completion];
}

- (void)convertToMP4Completed:(convertToMp4Completed)Completed
{
    NSString *filePath = self.videoPath;
    NSString *mp4FilePath = [filePath stringByReplacingOccurrencesOfString:@"mov" withString:@"mp4"];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        
        AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:nil];
        NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
        if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetHighestQuality];
            exportSession.outputURL = [NSURL fileURLWithPath:mp4FilePath];
            exportSession.outputFileType = AVFileTypeMPEG4;
            if ([[NSFileManager defaultManager] fileExistsAtPath:mp4FilePath])
            {
                [[NSFileManager defaultManager] removeItemAtPath:mp4FilePath error:nil];
            }
            [exportSession exportAsynchronouslyWithCompletionHandler:^(void)
             {
                 switch (exportSession.status) {
                     case AVAssetExportSessionStatusUnknown: {
                         NSLog(@"AVAssetExportSessionStatusUnknown");
                         break;
                     }
                     case AVAssetExportSessionStatusWaiting: {
                         NSLog(@"AVAssetExportSessionStatusWaiting");
                         break;
                     }
                     case AVAssetExportSessionStatusExporting: {
                         NSLog(@"AVAssetExportSessionStatusExporting");
                         break;
                     }
                     case AVAssetExportSessionStatusFailed: {
                         NSLog(@"AVAssetExportSessionStatusFailed error:%@", exportSession.error);
                         break;
                     }
                     case AVAssetExportSessionStatusCompleted: {
                         NSLog(@"AVAssetExportSessionStatusCompleted");
                         dispatch_async(dispatch_get_main_queue(),^{
                             Completed();
                         });
                         break;
                     }
                     default: {
                         NSLog(@"AVAssetExportSessionStatusCancelled");
                         break;
                     }
                 }
             }];
        }
    });
}


- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image {
    CGFloat w = CGImageGetWidth(image);
    CGFloat h = CGImageGetHeight(image);
    NSLog(@"%f,%f",w,h);
    if (w >= h) {
        
    } else {
        CGFloat t = w;
        w = h;
        h = t;
    }
    if (image) {
        CGSize size = CGSizeMake(400, 320);
        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                                 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                                 nil];
        CVPixelBufferRef pxbuffer = NULL;
        
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                              size.width,
                                              size.height,
                                              kCVPixelFormatType_32ARGB,
                                              (__bridge CFDictionaryRef) options,
                                              &pxbuffer);
        if (status != kCVReturnSuccess){
            NSLog(@"Failed to create pixel buffer");
        }
        
        CVPixelBufferLockBaseAddress(pxbuffer, 0);
        void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
        
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                     size.height, 8, 4*size.width, rgbColorSpace,
                                                     kCGImageAlphaPremultipliedFirst);
        //kCGImageAlphaNoneSkipFirst);
        CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                               CGImageGetHeight(image)), image);
        CGColorSpaceRelease(rgbColorSpace);
        CGContextRelease(context);
        
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        
        return pxbuffer;
    } else {
        return NULL;
    }
}

- (void)makeVideoWithImage:(NSArray *)images
                     audio:(NSString *)audioFile
                completion:(VideoBuildCompletion)completion{
    //获取音频的本地路径
    self.audioFile = audioFile;
    __weak __typeof(self) weakSelf = self;
    [self convertVideoWithImageArray:images Success:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        __weak __typeof(strongSelf) weakweakSelf = strongSelf;
        if (audioFile == nil) {
            if (completion) {
                               completion(strongSelf.videoPath);
                           }
            return ;
        }
        [strongSelf addAudioToVideoAudioPath:audioFile Completion:^{
            __strong __typeof(weakweakSelf) strongstrongSelf = weakweakSelf;
            [strongstrongSelf convertToMP4Completed:^{
                if (completion) {
                    completion(strongstrongSelf.videoPath);
                }
            }];
        }];
    } Fail:^(NSError *error) {
    }];
}

@end
