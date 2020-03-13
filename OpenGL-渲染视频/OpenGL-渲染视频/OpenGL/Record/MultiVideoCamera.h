//
//  MultiVideoCamera.h
//  OpenGL-渲染视频
//
//  Created by fuzhongw on 2020/3/13.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "MKBaseVideoCamera.h"
#import "MKGPUImageView.h"

@protocol MMultiVideoCameraDelegate <NSObject>

// 特效处理
- (void)effectsProcessingTexture:(GLuint)texture inputSize:(CGSize)newSize rotateMode:(MKGPUImageRotationMode)rotation;
// 渲染
- (void)renderTexture:(GLuint) inputTextureId inputSize:(CGSize)size rotateMode:(MKGPUImageRotationMode)rotation;
// 录制文件
- (void)didWriteMovieAtURL:(NSURL *_Nullable)outputURL;
@end

NS_ASSUME_NONNULL_BEGIN

@interface MultiVideoCamera : MKBaseVideoCamera
- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition size:(CGSize)newSize;

/// This determines the rotation applied to the output image, based on the source material
@property(readwrite, nonatomic) UIInterfaceOrientation outputImageOrientation;

/// These properties determine whether or not the two camera orientations should be mirrored. By default, both are NO.
@property(readwrite, nonatomic) BOOL horizontallyMirrorFrontFacingCamera, horizontallyMirrorRearFacingCamera;

@property (nonatomic, weak) id <MMultiVideoCameraDelegate> delegate;

- (void)startWriting;
- (void)stopWriting;
@end

NS_ASSUME_NONNULL_END
