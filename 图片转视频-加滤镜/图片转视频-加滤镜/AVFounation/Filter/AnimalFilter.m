//
//  AnimalFilter.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/8.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "AnimalFilter.h"
#import <GLKit/GLKit.h>
#import "GLESMath.h"

typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;

@interface AnimalFilter()
@property (nonatomic, assign) GLuint program2; // 着色器程序
@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存
@property (nonatomic, assign) GLuint textureID; // 纹理 ID
@property (nonatomic, assign) GLuint backTextureID; // 纹理 ID
@property (nonatomic, assign) SenceVertex *vertices;
@property (nonatomic, assign) BOOL isFBO; // 纹理 ID
@property(nonatomic,assign)   GLuint myColorRenderBuffer;
@property(nonatomic,assign)   GLuint myColorFrameBuffer;
@property (nonatomic, assign) KSMatrix4 kmodelViewMatrix;
@property (nonatomic, assign) SenceVertex *vertices2;
@property (nonatomic, assign) GLuint vertexBuffer2; // 顶点缓存

@end

@implementation AnimalFilter
#pragma mark - Public
-(void)dealloc{
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }

    if (_vertices2) {
         free(_vertices2);
         _vertices2 = nil;
     }

    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }

    if (_vertexBuffer2) {
        glDeleteBuffers(1, &_vertexBuffer2);
        _vertexBuffer2 = 0;
    }
}

-(instancetype)init{
    if (self = [super init]) {

        self.vertices = malloc(sizeof(SenceVertex) * 4);

        self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
        self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
        self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
        self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};

        self.vertices2 = malloc(sizeof(SenceVertex) * 4);

        self.vertices2[0] = (SenceVertex){{-1.0, 1.0, 0}, {0, 1}};
        self.vertices2[1] = (SenceVertex){{-0.8, -1.0, 0}, {0, 0}};
        self.vertices2[2] = (SenceVertex){{1.0, 1.0, 0}, {1, 1}};
        self.vertices2[3] = (SenceVertex){{1.0, -1.0, 0}, {1, 0}};
    }
    return self;
}

- (CVPixelBufferRef)outputPixelBuffer {
    if (!self.pixelBuffer) {
        return nil;
    }
    [self startRendering];
    return self.resultPixelBuffer;
}


#pragma mark - Private

/// 开始渲染视频图像
- (void)startRendering {
    // 可以对比下两种渲染方式
    CVPixelBufferRef pixelBuffer = [self renderByGPUImage:self.pixelBuffer];  // GPUImage
    self.resultPixelBuffer = pixelBuffer;
    CVPixelBufferRelease(pixelBuffer);
}

// 用 GPUImage 加滤镜
- (CVPixelBufferRef)renderByGPUImage:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferRetain(pixelBuffer);

    __block CVPixelBufferRef output = nil;
    runSynchronouslyOnVideoProcessingQueue(^{
        [SourceEAGLContext useImageProcessingContext];


        GLuint textureID = [self.pixelBufferHelper convertYUVPixelBufferToTexture:pixelBuffer];
        CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                                 CVPixelBufferGetHeight(pixelBuffer));
//        self.textureID = textureID;

        GLuint resultTextureID = [self commonInit:size foreTextture:textureID];

        output = [self.pixelBufferHelper convertTextureToPixelBuffer:resultTextureID
                                                         textureSize:size];

        glDeleteTextures(1, &resultTextureID);

        glDeleteTextures(1, &textureID);
        glDeleteTextures(1, &self->_backTextureID);

    });
    CVPixelBufferRelease(pixelBuffer);

    return output;
}

- (GLuint)createTextureWithImage:(UIImage *)image {
    
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, cgImageRef);

    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindTexture(GL_TEXTURE_2D, 0);

    CGContextRelease(context);
    free(imageData);

    return textureID;
}

- (GLuint)commonInit:(CGSize) size foreTextture:(GLuint)fortextureID {


    GLuint textureID;
    //    // FBO
    GLuint renderBuffer;
    GLuint frameBuffer;

    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);

    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              renderBuffer);

    // texture
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureID, 0);


    glViewport(0, 0, size.width,size.height);

    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
//    self.vertexBuffer = vertexBuffer; // 将顶点缓存保存，退出时才释放

    [self setupScaleShaderProgramforeTextture:fortextureID];

    glDeleteFramebuffers(1, &frameBuffer);
    glDeleteRenderbuffers(1, &renderBuffer);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vertexBuffer);
    vertexBuffer = 0;

//    glDeleteBuffers(1, &_vertexBuffer2);
//    _vertexBuffer2 = 0;

    glFlush();
    return textureID;
}

// 缩放着色器程序
- (void)setupScaleShaderProgramforeTextture:(GLuint)fortextureID {
      //4.判断self.myProgram是否存在，存在则清空其文件
    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }

    self.program = [MFShaderHelper programWithShaderName:@"Normal"];

    glUseProgram(self.program);

    GLuint positionSlot = glGetAttribLocation(self.program, "position");//位置
    GLuint textureSlot = glGetUniformLocation(self.program, "renderTexture");//纹理
    GLuint textureCoordsSlot = glGetAttribLocation(self.program, "inputTextureCoordinate");//纹理坐标

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fortextureID);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(textureSlot, 0);


    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));

    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));

    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0, 0, 0, 0.5);
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);


    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices2, GL_STATIC_DRAW);
    _vertexBuffer2 = vertexBuffer;
    if (self.program2) {
         glDeleteProgram(self.program2);
         self.program2 = 0;
     }

     self.program2 = [MFShaderHelper programWithShaderName:@"test03"];

     glUseProgram(self.program2);

     GLuint positionSlot2 = glGetAttribLocation(self.program2, "Position");//位置
     GLuint textureSlot2 = glGetUniformLocation(self.program2, "Texture");//纹理
     GLuint textureCoordsSlot2 = glGetAttribLocation(self.program2, "TextureCoords");//纹理坐标

    //        = btextureID;
    GLuint modelViewMatrixSlot = glGetUniformLocation(self.program2, "modelViewMatrix");
    KSMatrix4 modelViewMatrix = [self createModelViewMatrix];
    glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&modelViewMatrix.m[0][0]);


     glActiveTexture(GL_TEXTURE1);
     glBindTexture(GL_TEXTURE_2D,  self.backTextureID);
     glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
     glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
     glUniform1i(textureSlot2, 1);


     glEnableVertexAttribArray(positionSlot2);
     glVertexAttribPointer(positionSlot2, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));

     glEnableVertexAttribArray(textureCoordsSlot2);
     glVertexAttribPointer(textureCoordsSlot2, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));


     // 清除画布
//    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0, 0, 0, 0.0);

     // 重绘
     glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
     glDeleteBuffers(1, &vertexBuffer);
    vertexBuffer = 0;

}

- (KSMatrix4)createModelViewMatrix {

    float currentTime =  CMTimeGetSeconds(self.currTime);

    if (currentTime <= 6) {
        self.backTextureID  =  [self createTextureWithImage:[UIImage imageNamed:@"1"]];
        return [self updateModelViewMatrix1];
    }else if(currentTime <= 10){
        self.backTextureID  =  [self createTextureWithImage:[UIImage imageNamed:@"6"]];

        return [self updateModelViewMatrix2];

    }
//    else if(currentTime <= 16){
//        self.backTextureID  =  [self createTextureWithImage:[UIImage imageNamed:@"8"]];
//
//        return [self updateModelViewMatrix5];
//
//    }
    self.backTextureID  =  [self createTextureWithImage:[UIImage imageNamed:@"10"]];
    return [self updateModelViewMatrix3];


}

- (KSMatrix4)updateModelViewMatrix3 {

    float totalTime = 5;
    float currentTime =  CMTimeGetSeconds(self.currTime) - 6;
    float duration5 = fmodf(currentTime, totalTime);

    KSMatrix4 modelViewMatrix;
    //(1)获取单元矩阵
    ksMatrixLoadIdentity(&modelViewMatrix);
    float alphaValue = 1.0;

    if (duration5 <= totalTime) {

        if (duration5 <= 2) {
            ksTranslate(&modelViewMatrix, -1.0, -1.0, 0);

//            //(2)缩放
            CGFloat a =  M_PI_2 - M_PI_4 * duration5;
            GLfloat r = 1.12;
            GLfloat x = r * sinf(a);
            GLfloat y = r - r * cosf(a);
            GLfloat rx = -1.0 + x;
            GLfloat ry = 1.0 - y;
            NSLog(@"rx = %lf ,ry =%lf ",rx,ry);

            ksTranslate(&modelViewMatrix, -rx, ry, 0);

            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  15 * duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);

        }else if (duration5 <= 4.5){
            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);

           //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

        }else{

            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);
            //(3)创建一个4 * 4 矩阵，平移矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            float ss = (totalTime - duration5) / (totalTime - 4.5);

            GLfloat elValue =  2 + -tan(M_PI / 3.0) * ss;
            //            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);
            // 平移
            ksTranslate(&slateionMatrix, elValue, elValue,0.0);
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);
            alphaValue = ss;

        }
        GLuint alpha = glGetUniformLocation(self.program2, "alpha");
        glUniform1f(alpha, alphaValue);

    }

    return modelViewMatrix ;
}

- (KSMatrix4)updateModelViewMatrix2 {

    float totalTime = 5;
    float currentTime =  CMTimeGetSeconds(self.currTime) - 6;
    float duration5 = fmodf(currentTime, totalTime);

    KSMatrix4 modelViewMatrix;
    //(1)获取单元矩阵
    ksMatrixLoadIdentity(&modelViewMatrix);
    float alphaValue = 1.0;

    if (duration5 <= totalTime) {

        if (duration5 <= 1.5) {

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.5 * duration5;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);

        }else if (duration5 <= 4.5){

           //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

        }else{

            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);
            //(3)创建一个4 * 4 矩阵，平移矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            float ss = (totalTime - duration5) / (totalTime - 4.5);

            GLfloat elValue =  2 + -tan(M_PI / 3.0) * ss;
            //            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);
            NSLog(@"elValue = %lf",elValue);
            // 平移
            ksTranslate(&slateionMatrix, elValue, elValue,0.0);
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);
            alphaValue = ss;

        }
        GLuint alpha = glGetUniformLocation(self.program2, "alpha");
        glUniform1f(alpha, alphaValue);

    }

    return modelViewMatrix ;
}
- (KSMatrix4)updateModelViewMatrix1 {

    float totalTime = 6;
    float currentTime =  CMTimeGetSeconds(self.currTime);
    float duration5 = fmodf(currentTime, totalTime);

    KSMatrix4 modelViewMatrix;
    //(1)获取单元矩阵
    ksMatrixLoadIdentity(&modelViewMatrix);
    float alphaValue = 1.0;

    if (duration5 <= totalTime) {

        if (duration5 <= 2) {

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.3 * duration5;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);

            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  -60 + 32 * duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

        }else if (duration5 <= 5.5){
            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);

            //(3)创建一个4 * 4 矩阵，平移矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            // 平移
            //(2)平移，z轴平移-10
            ksTranslate(&slateionMatrix, -0.001, 0.001,0.0);
            //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

        }else{

            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);
            //(3)创建一个4 * 4 矩阵，平移矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            float ss = (totalTime - duration5) / (totalTime - 5.5);

            GLfloat elValue =  2 + -tan(M_PI / 3.0) * ss;
            //            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);

            // 平移
            ksTranslate(&slateionMatrix, -elValue, 0.0,0.0);
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);
            alphaValue = ss;

        }
        GLuint alpha = glGetUniformLocation(self.program2, "alpha");
        glUniform1f(alpha, alphaValue);

    }

    return modelViewMatrix ;
}

- (KSMatrix4)updateModelViewMatrix5 {

    float totalTime = 6;
    float currentTime =  CMTimeGetSeconds(self.currTime);
    float duration5 = fmodf(currentTime, totalTime);
    float alphaValue = 1.0;

    KSMatrix4 modelViewMatrix;
    //(1)获取单元矩阵
    ksMatrixLoadIdentity(&modelViewMatrix);

    if (duration5 <= totalTime) {

        if (duration5 <= 2) {

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.3 * duration5;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);


            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  -30 + 20 * duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);


        }else if (duration5 <= 5){

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);
            GLfloat elValue = 0.1 -0.1 * sinf(duration5);

            // 平移
            //(2)平移，z轴平移-10
            ksTranslate(&slateionMatrix, 0.0, fabsf(elValue),0.0);
            //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);

//            (3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat rotatlValue =  -30 + 20 * 2.0;
            ksRotate(&_rotationMatrix,rotatlValue , 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.3 * 2.0;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);

            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

        }else{
            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);
            alphaValue = (totalTime - duration5) / (totalTime - 4.5);

        }
        NSLog(@"alpha = %lf",alphaValue);

        GLuint alpha = glGetUniformLocation(self.program, "alpha");
        glUniform1f(alpha, alphaValue);

    }

    return modelViewMatrix ;
}
- (KSMatrix4)updateModelViewMatrix4 {

    float totalTime = 5;
    float currentTime =  CMTimeGetSeconds(self.currTime);
    float duration5 = fmodf(currentTime, totalTime);

    KSMatrix4 modelViewMatrix;
    //(1)获取单元矩阵
    ksMatrixLoadIdentity(&modelViewMatrix);

    if (duration5 <= totalTime) {

        if (duration5 <= 2) {

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.3 * duration5;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);


            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat elValue =  -30 + 20 * duration5;
            ksRotate(&_rotationMatrix, elValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);


        }else if (duration5 <= 4.5){

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);
            GLfloat elValue = 0.1 -0.1 * sinf(duration5);

            NSLog(@"elValue = %lf",elValue);

            // 平移
            //(2)平移，z轴平移-10
            ksTranslate(&slateionMatrix, 0.0, fabsf(elValue),0.0);
            //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);

//            (3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            GLfloat rotatlValue =  -30 + 20 * 2.0;
            ksRotate(&_rotationMatrix,rotatlValue , 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);
            //(6)初始化为单元矩阵
            ksMatrixLoadIdentity(&_kmodelViewMatrix);
            ksMatrixMultiply(&_kmodelViewMatrix, &modelViewMatrix, &_kmodelViewMatrix);

            //(2)缩放
            GLfloat scalelValue =  0.2 + 0.3 * 2.0;
            ksScale(&modelViewMatrix, scalelValue, scalelValue + 0.05, 1.0);

        }else{
            ksMatrixMultiply(&modelViewMatrix, &_kmodelViewMatrix, &modelViewMatrix);

            //(3)创建一个4 * 4 矩阵，平移矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            float ss = (totalTime - duration5) / (totalTime - 4.5);

            GLfloat elValue =  2 + -tan(M_PI / 3.0) * ss;
//            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);

            // 平移
            ksTranslate(&slateionMatrix, -elValue, -elValue,0.0);
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);
        }

    }

    return modelViewMatrix ;
}


@end
