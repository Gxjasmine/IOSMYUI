//
//  IOpenGLRenderer.m
//  iMyVideoEditor
//
//  Created by fuzhongw on 2020/4/24.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "IOpenGLRenderer.h"
#import "MFShaderHelper.h"

enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_RENDER_TRANSFORM_Y,
    UNIFORM_RENDER_TRANSFORM_UV,
       NUM_UNIFORMS
};
extern GLint uniforms[NUM_UNIFORMS];

enum
{
    ATTRIB_VERTEX_Y,
    ATTRIB_TEXCOORD_Y,
    ATTRIB_VERTEX_UV,
    ATTRIB_TEXCOORD_UV,
       NUM_ATTRIBUTES
};
#warning 解决内存过高，崩溃的问题

@interface IOpenGLRenderer()
@property (nonatomic, strong) EAGLContext *currentContext;

@property (nonatomic, assign) CVOpenGLESTextureCacheRef videoTextureCache;
@property (nonatomic, assign) GLuint offscreenBufferHandle;
@property(nonatomic, assign) GLuint program;
@property (nonatomic, assign) GLuint VBO;
@property (nonatomic, assign) CVOpenGLESTextureRef renderTexture;

@end

@implementation IOpenGLRenderer

- (void)setRenderTexture:(CVOpenGLESTextureRef)renderTexture {
    if (_renderTexture &&
        renderTexture &&
        CFEqual(renderTexture, _renderTexture)) {
        return;
    }
    if (renderTexture) {
        CFRetain(renderTexture);
    }
    if (_renderTexture) {
        CFRelease(_renderTexture);
    }
    _renderTexture = renderTexture;
}


- (id)init
{
    self = [super init];
    if(self) {
        _currentContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext:_currentContext];

        [self setupOffscreenRenderContext];
        [self loadShaders];
        [self setupVBO];

        [EAGLContext setCurrentContext:nil];
    }

    return self;
}

- (void)setupOffscreenRenderContext
{
    //-- Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
        _videoTextureCache = NULL;
    }
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _currentContext, NULL, &_videoTextureCache);
    if (err != noErr) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
    }

    glGenFramebuffers(1, &_offscreenBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _offscreenBufferHandle);
}

- (BOOL)loadShaders
{
    self.program = [MFShaderHelper programWithShaderName:@"YUVConversion"];;
//
//    glBindAttribLocation(_program, ATTRIB_VERTEX_Y, "position");
//    glBindAttribLocation(_program, ATTRIB_TEXCOORD_Y, "inputTextureCoordinate");
//    uniforms[UNIFORM_Y] = glGetUniformLocation(_program, "luminanceTexture");
//    uniforms[UNIFORM_UV] = glGetUniformLocation(_program, "chrominanceTexture");
//
//    uniforms[UNIFORM_RENDER_TRANSFORM_Y] = glGetUniformLocation(_program, "colorConversionMatrix");

    return self.program;
}

- (void)dealloc
{
    if (_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    if (_offscreenBufferHandle) {
        glDeleteFramebuffers(1, &_offscreenBufferHandle);
        _offscreenBufferHandle = 0;
    }
}

- (CVOpenGLESTextureRef)lumaTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef lumaTexture = NULL;
    CVReturn err;

    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }

    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);

    // CVOpenGLTextureCacheCreateTextureFromImage will create GL texture optimally from CVPixelBufferRef.
    // Y
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE,
                                                       (int)CVPixelBufferGetWidth(pixelBuffer),
                                                       (int)CVPixelBufferGetHeight(pixelBuffer),
                                                       GL_LUMINANCE,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &lumaTexture);

    if (!lumaTexture || err) {
        NSLog(@"Error at creating luma texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }

bail:
    return lumaTexture;
}

- (CVOpenGLESTextureRef)chromaTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef chromaTexture = NULL;
    CVReturn err;

    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        goto bail;
    }

    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);

    // CVOpenGLTextureCacheCreateTextureFromImage will create GL texture optimally from CVPixelBufferRef.
    // UV
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_LUMINANCE_ALPHA,
                                                       (int)CVPixelBufferGetWidth(pixelBuffer) * 0.5,
                                                       (int)CVPixelBufferGetHeight(pixelBuffer) * 0.5,
                                                       GL_LUMINANCE_ALPHA,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &chromaTexture);

    if (!chromaTexture || err) {
        NSLog(@"Error at creating chroma texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }

bail:
    return chromaTexture;
}

-(CVOpenGLESTextureRef)sourceTextureForPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVOpenGLESTextureRef sourceTexture = NULL;
    CVReturn err;
    if (! self.videoTextureCache) {
        NSLog(@"Transiton No video texture cache");
        goto bail;
    }

    CVOpenGLESTextureCacheFlush( self.videoTextureCache, 0);

    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,  self.videoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, (int)CVPixelBufferGetWidth(pixelBuffer), (int)CVPixelBufferGetHeight(pixelBuffer), GL_BGRA, GL_UNSIGNED_BYTE, 0, &sourceTexture);
    if (err) {
        NSLog(@"Transiton Error at creating luma texture using CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
bail:
    return sourceTexture;
}

- (GLuint)convertRGBPixelBufferToTexture:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return 0;
    }

    CGSize textureSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                                    CVPixelBufferGetHeight(pixelBuffer));
    CVOpenGLESTextureRef texture = nil;
    CVOpenGLESTextureCacheFlush( self.videoTextureCache, 0);

    CVReturn status = CVOpenGLESTextureCacheCreateTextureFromImage(NULL,
                                                                   self.videoTextureCache,
                                                                   pixelBuffer,
                                                                   NULL,
                                                                   GL_TEXTURE_2D,
                                                                   GL_RGBA,
                                                                   textureSize.width,
                                                                   textureSize.height,
                                                                   GL_BGRA,
                                                                   GL_UNSIGNED_BYTE,
                                                                   0,
                                                                   &texture);

    if (status != kCVReturnSuccess) {
        NSLog(@"Can't create texture");
    }

    self.renderTexture = texture;
    CFRelease(texture);
    return CVOpenGLESTextureGetName(texture);
}

#warning 解决内存过高，崩溃的问题
- (CVPixelBufferRef)renderPixelBufferSourceBuffer:(CVPixelBufferRef)sourceBuffer forTweenFactor:(float)tween{
    [EAGLContext setCurrentContext:self.currentContext];

    if (sourceBuffer != NULL ) {

        CVOpenGLESTextureRef foregroundLumaTexture  = [self lumaTextureForPixelBuffer:sourceBuffer];
        CVOpenGLESTextureRef foregroundChromaTexture = [self chromaTextureForPixelBuffer:sourceBuffer];

        CGSize textureSize = CGSizeMake(CVPixelBufferGetWidth(sourceBuffer),
                                        CVPixelBufferGetHeight(sourceBuffer));

        glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);

        glUseProgram(self.program);

        CVPixelBufferRef pixelBuffer;
        CVOpenGLESTextureRef renderTexture = nil;
                // By default, all framebuffers on iOS 5.0+ devices are backed by texture caches, using one shared cache
        {
        #if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
//                    CVOpenGLESTextureCacheRef coreVideoTextureCache = [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache];
                    // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/

                    CFDictionaryRef empty; // empty value for attr value.
                    CFMutableDictionaryRef attrs;
                    empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
                    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);


                    /**

                     CVPixelBufferRef pixelBuffer;
                     NSDictionary *pixelBufferAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}};
                     CVReturn status = CVPixelBufferCreate(nil,
                                                           size.width,
                                                           size.height,
                                                           kCVPixelFormatType_32BGRA,
                                                           (__bridge CFDictionaryRef _Nullable)(pixelBufferAttributes),
                                                           &pixelBuffer);
                     if (status != kCVReturnSuccess) {
                         NSLog(@"Can't create pixelbuffer");
                     }
                     */

                    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (int)textureSize.width, (int)textureSize.height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer);
                    if (err)
                    {
                        NSLog(@"FBO size: %f, %f", textureSize.width, textureSize.height);
                        NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
                    }

                    err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, self.videoTextureCache, pixelBuffer,
                                                                        NULL, // texture attributes
                                                                        GL_TEXTURE_2D,
                                                                        GL_RGBA, // opengl format
                                                                        (int)textureSize.width,
                                                                        (int)textureSize.height,
                                                                        GL_BGRA, // native iOS format
                                                                        GL_UNSIGNED_BYTE,
                                                                        0,
                                                                        &renderTexture);
                    if (err)
                    {
                        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
                    }

                    CFRelease(attrs);
                    CFRelease(empty);

                    glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));

                    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

                    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
        #endif
                }


//        GPUTextureOptions defaultTextureOptions;
//        defaultTextureOptions.minFilter = GL_LINEAR;
//        defaultTextureOptions.magFilter = GL_LINEAR;
//        defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
//        defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
//        defaultTextureOptions.internalFormat = GL_RGBA;
//        defaultTextureOptions.format = GL_BGRA;
//        defaultTextureOptions.type = GL_UNSIGNED_BYTE;
//        _outputFramebuffer =  [[GPUImageFramebuffer alloc] initWithSize:textureSize textureOptions:defaultTextureOptions onlyTexture:NO];
////         _outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:textureSize onlyTexture:NO];
//        [_outputFramebuffer activateFramebuffer];
//
//        [_outputFramebuffer byteBuffer];

        glViewport(0, 0, (int)CVPixelBufferGetWidthOfPlane(sourceBuffer, 0), (int)CVPixelBufferGetHeightOfPlane(sourceBuffer, 0));

        // Y planes of foreground and background frame are used to render the Y plane of the destination frame
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(foregroundLumaTexture), CVOpenGLESTextureGetName(foregroundLumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glUniform1i(glGetUniformLocation(self.program, "luminanceTexture"), 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(CVOpenGLESTextureGetTarget(foregroundChromaTexture), CVOpenGLESTextureGetName(foregroundChromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glUniform1i(glGetUniformLocation(self.program, "chrominanceTexture"), 1);

        // Attach the destination texture as a color attachment to the off screen frame buffer
//        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(targetTextureID), CVOpenGLESTextureGetName(targetTextureID), 0);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
            goto bail;
        }

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

//        GLfloat quadVertexData1 [] = {
//            -1, 1, 0,
//            -1, -1, 0,
//            1, 1, 0,
//            1, -1, 0,
//        };
//
//        GLfloat quadTextureData1 [] = {
//            0, 1,
//            0, 0,
//            1, 1,
//            1, 0,
//        };


        /*

         glBindAttribLocation(_program, ATTRIB_VERTEX_Y, "position");
         glBindAttribLocation(_program, ATTRIB_TEXCOORD_Y, "inputTextureCoordinate");
         uniforms[UNIFORM_Y] = glGetUniformLocation(_program, "luminanceTexture");
         uniforms[UNIFORM_UV] = glGetUniformLocation(_program, "chrominanceTexture");

         uniforms[UNIFORM_RENDER_TRANSFORM_Y] = glGetUniformLocation(_program, "colorConversionMatrix");
         **/




        GLfloat kXDXPreViewColorConversion601FullRange[] = {
            1.0,    1.0,    1.0,
            0.0,    -0.343, 1.765,
            1.4,    -0.711, 0.0,
        };

        GLuint yuvConversionMatrixUniform = glGetUniformLocation(self.program, "colorConversionMatrix");
        glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, kXDXPreViewColorConversion601FullRange);

//        GLfloat kXDXPreViewColorConversion601FullRange[] = {
//            1.0,    1.0,    1.0,
//            0.0,    -0.343, 1.765,
//            1.4,    -0.711, 0.0,
//        };
//
//
//        glUniformMatrix3fv(uniforms[UNIFORM_RENDER_TRANSFORM_Y], 1, GL_FALSE, kXDXPreViewColorConversion601FullRange);
//
//        glUniform1i(uniforms[UNIFORM_Y], 0);
//        glUniform1i(uniforms[UNIFORM_UV], 1);

        // VBO
        glBindBuffer(GL_ARRAY_BUFFER, self.VBO);
        GLuint positionSlot = glGetAttribLocation(self.program, "position");
        glEnableVertexAttribArray(positionSlot);
        glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);

        GLuint textureSlot = glGetAttribLocation(self.program, "inputTextureCoordinate");
        glEnableVertexAttribArray(textureSlot);
        glVertexAttribPointer(textureSlot, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3* sizeof(float)));

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//        glVertexAttribPointer(ATTRIB_VERTEX_Y, 3, GL_FLOAT, 0, 0, quadVertexData1);
//        glEnableVertexAttribArray(ATTRIB_VERTEX_Y);
//
//        glVertexAttribPointer(ATTRIB_TEXCOORD_Y, 2, GL_FLOAT, 0, 0, quadTextureData1);
//        glEnableVertexAttribArray(ATTRIB_TEXCOORD_Y);
//
//        // Draw the foreground frame
//        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glFlush();

    bail:
        CFRelease(foregroundLumaTexture);
        CFRelease(foregroundChromaTexture);
        CFRelease(renderTexture);
//        CFRelease(targetTextureID);
//        glDeleteTextures(1, &targetTextureID);
        // Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);

        [EAGLContext setCurrentContext:nil];

        return pixelBuffer;
    }

    return nil;
}

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer sourceBuffer:(CVPixelBufferRef)sourceBuffer forTweenFactor:(float)tween{
    [EAGLContext setCurrentContext:self.currentContext];

    if (sourceBuffer != NULL ) {

        CVOpenGLESTextureRef foregroundLumaTexture  = [self lumaTextureForPixelBuffer:sourceBuffer];
        CVOpenGLESTextureRef foregroundChromaTexture = [self chromaTextureForPixelBuffer:sourceBuffer];

        CGSize textureSize = CGSizeMake(CVPixelBufferGetWidth(destinationPixelBuffer),
                                        CVPixelBufferGetHeight(destinationPixelBuffer));


//        CVPixelBufferRef pixelBuffer = [self createPixelBufferWithSize:textureSize];

        CVOpenGLESTextureRef targetTextureID = [self sourceTextureForPixelBuffer:destinationPixelBuffer];
//        CVOpenGLESTextureRef targetTextureID  = [self lumaTextureForPixelBuffer:destinationPixelBuffer];
//        GLuint targetTextureID = [self convertRGBPixelBufferToTexture:destinationPixelBuffer];

        glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);

        glUseProgram(self.program);

        glViewport(0, 0, (int)CVPixelBufferGetWidthOfPlane(destinationPixelBuffer, 0), (int)CVPixelBufferGetHeightOfPlane(destinationPixelBuffer, 0));

        // Y planes of foreground and background frame are used to render the Y plane of the destination frame
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLESTextureGetTarget(foregroundLumaTexture), CVOpenGLESTextureGetName(foregroundLumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glUniform1i(glGetUniformLocation(self.program, "luminanceTexture"), 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(CVOpenGLESTextureGetTarget(foregroundChromaTexture), CVOpenGLESTextureGetName(foregroundChromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glUniform1i(glGetUniformLocation(self.program, "chrominanceTexture"), 1);

        // Attach the destination texture as a color attachment to the off screen frame buffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(targetTextureID), CVOpenGLESTextureGetName(targetTextureID), 0);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
            goto bail;
        }

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

//        GLfloat quadVertexData1 [] = {
//            -1, 1, 0,
//            -1, -1, 0,
//            1, 1, 0,
//            1, -1, 0,
//        };
//
//        GLfloat quadTextureData1 [] = {
//            0, 1,
//            0, 0,
//            1, 1,
//            1, 0,
//        };


        /*

         glBindAttribLocation(_program, ATTRIB_VERTEX_Y, "position");
         glBindAttribLocation(_program, ATTRIB_TEXCOORD_Y, "inputTextureCoordinate");
         uniforms[UNIFORM_Y] = glGetUniformLocation(_program, "luminanceTexture");
         uniforms[UNIFORM_UV] = glGetUniformLocation(_program, "chrominanceTexture");

         uniforms[UNIFORM_RENDER_TRANSFORM_Y] = glGetUniformLocation(_program, "colorConversionMatrix");
         **/




        GLfloat kXDXPreViewColorConversion601FullRange[] = {
            1.0,    1.0,    1.0,
            0.0,    -0.343, 1.765,
            1.4,    -0.711, 0.0,
        };

        GLuint yuvConversionMatrixUniform = glGetUniformLocation(self.program, "colorConversionMatrix");
        glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, kXDXPreViewColorConversion601FullRange);

//        GLfloat kXDXPreViewColorConversion601FullRange[] = {
//            1.0,    1.0,    1.0,
//            0.0,    -0.343, 1.765,
//            1.4,    -0.711, 0.0,
//        };
//
//
//        glUniformMatrix3fv(uniforms[UNIFORM_RENDER_TRANSFORM_Y], 1, GL_FALSE, kXDXPreViewColorConversion601FullRange);
//
//        glUniform1i(uniforms[UNIFORM_Y], 0);
//        glUniform1i(uniforms[UNIFORM_UV], 1);

        // VBO
        glBindBuffer(GL_ARRAY_BUFFER, self.VBO);
        GLuint positionSlot = glGetAttribLocation(self.program, "position");
        glEnableVertexAttribArray(positionSlot);
        glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);

        GLuint textureSlot = glGetAttribLocation(self.program, "inputTextureCoordinate");
        glEnableVertexAttribArray(textureSlot);
        glVertexAttribPointer(textureSlot, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3* sizeof(float)));

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//        glVertexAttribPointer(ATTRIB_VERTEX_Y, 3, GL_FLOAT, 0, 0, quadVertexData1);
//        glEnableVertexAttribArray(ATTRIB_VERTEX_Y);
//
//        glVertexAttribPointer(ATTRIB_TEXCOORD_Y, 2, GL_FLOAT, 0, 0, quadTextureData1);
//        glEnableVertexAttribArray(ATTRIB_TEXCOORD_Y);
//
//        // Draw the foreground frame
//        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glFlush();

    bail:
        CFRelease(foregroundLumaTexture);
        CFRelease(foregroundChromaTexture);
        CFRelease(targetTextureID);
//        glDeleteTextures(1, &targetTextureID);
        // Periodic texture cache flush every frame
        CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);

        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setupVBO {
    float vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
        -1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 0.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f, 1.0f, 1.0f,
    };

    glGenBuffers(1, &_VBO);
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type source:(NSString *)sourceString
{
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: Empty source string");
        return NO;
    }

    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }

    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);

#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif

    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }

    return YES;
}

#if defined(DEBUG)

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;

    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }

    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }

    return YES;
}

#endif

@end
