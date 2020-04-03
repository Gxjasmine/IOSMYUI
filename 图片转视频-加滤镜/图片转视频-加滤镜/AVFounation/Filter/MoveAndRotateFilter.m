//
//  MoveAndRotateFilter.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/3/30.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "MoveAndRotateFilter.h"
#import <GLKit/GLKit.h>

typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;

@interface MoveAndRotateFilter()
@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存
@property (nonatomic, assign) GLuint textureID; // 纹理 ID
@property (nonatomic, assign) SenceVertex *vertices;

@end

@implementation MoveAndRotateFilter

#pragma mark - Public
-(instancetype)init{
    if (self = [super init]) {

        self.vertices = malloc(sizeof(SenceVertex) * 4);

        self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
        self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
        self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
        self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};
//        [self startFilerAnimation];
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
//    CVPixelBufferRef pixelBuffer = [self renderByCIImage:self.pixelBuffer];  // CIImage
    self.resultPixelBuffer = pixelBuffer;
    CVPixelBufferRelease(pixelBuffer);
}

// 用 CIImage 加滤镜
- (CVPixelBufferRef)renderByCIImage:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferRetain(pixelBuffer);

    CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                             CVPixelBufferGetHeight(pixelBuffer));
    CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
    // 加一层淡黄色滤镜
    CIImage *filterImage = [CIImage imageWithColor:[CIColor colorWithRed:255.0 / 255
                                                                   green:0 / 255
                                                                    blue:0 / 255
                                                                   alpha:0.5]];
    image = [filterImage imageByCompositingOverImage:image];

    CVPixelBufferRef output = [self.pixelBufferHelper createPixelBufferWithSize:size];
    [self.context render:image toCVPixelBuffer:output];

    CVPixelBufferRelease(pixelBuffer);
    return output;
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
        self.textureID = textureID;
       GLuint resultTextureID = [self commonInit:size];
//
        output = [self.pixelBufferHelper convertTextureToPixelBuffer:resultTextureID
                                                         textureSize:size];

//        [textureOutput doneWithTexture];

        glDeleteTextures(1, &resultTextureID);

        glDeleteTextures(1, &textureID);

    });
    CVPixelBufferRelease(pixelBuffer);

    return output;
}

- (GLuint)commonInit:(CGSize) size {


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
    self.vertexBuffer = vertexBuffer; // 将顶点缓存保存，退出时才释放

    [self setupScaleShaderProgram];

    glDeleteFramebuffers(1, &frameBuffer);
    glDeleteRenderbuffers(1, &renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &_vertexBuffer);

    glFlush();
    return textureID;
}

// 缩放着色器程序
- (void)setupScaleShaderProgram {

      //4.判断self.myProgram是否存在，存在则清空其文件
    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }

    self.program = [MFShaderHelper programWithShaderName:@"moveRotate"];

    glUseProgram(self.program);

    GLuint positionSlot = glGetAttribLocation(self.program, "Position");//位置
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");//纹理
    GLuint textureCoordsSlot = glGetAttribLocation(self.program, "TextureCoords");//纹理坐标

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(textureSlot, 0);

    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));

    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));


    //旋转
    GLuint modelViewMatrixSlot = glGetUniformLocation(self.program, "modelViewMatrix");
    GLKMatrix4 modelViewMatrix = [self updateModelViewMatrix];


    //(7)将模型视图矩阵传递到顶点着色器
    /*
     void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
     参数列表：
     location:指要更改的uniform变量的位置
     count:更改矩阵的个数
     transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
     value:执行count个元素的指针，用来更新指定uniform变量
     */
    glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)modelViewMatrix.m);

    [self timeAction];

}

// 在update中修改数据
- (GLKMatrix4)updateModelViewMatrix {

   GLKMatrix4 modelViewMatrix =  GLKMatrix4Identity;

    float currentTime =  CMTimeGetSeconds(self.currTime);
    GLfloat elValue = sinf(currentTime);
    NSLog(@"elValue = %lf",elValue);

    float d = fmodf(currentTime, 1.0) * 2;
    NSLog(@"currentTime = %lf,fmodf = %lf",currentTime,d);

    // 平移
    GLKMatrix4 translateMatrix2 = GLKMatrix4MakeTranslation(d, 0.0, 0.0);

    // 缩放
    GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(elValue, elValue, 1.0);

    // 旋转
    GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(elValue , 0.0, 0.0, 1.0);

    modelViewMatrix = GLKMatrix4Multiply(translateMatrix2, scaleMatrix);
    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotateMatrix);

    return modelViewMatrix;

//    // 缩放
//    GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(elValue, elValue, 1.0);
//
//    // 旋转
//    GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(elValue , 0.0, 0.0, 1.0);
//
//    // 平移
//    GLKMatrix4 translateMatrix = GLKMatrix4MakeTranslation(elValue, elValue, 0.0);
//
//    //                        平移              旋转           缩放
    // transformMatrix = translateMatrix * rotateMatrix * scaleMatrix
    // 矩阵会按照从右到左的顺序应用到position上。也就是先缩放（scale）,再旋转（rotate）,最后平移（translate）
//    // 如果这个顺序反过来，就完全不同了。从线性代数角度来讲，就是矩阵A乘以矩阵B不等于矩阵B乘以矩阵A。
//    modelViewMatrix = GLKMatrix4Multiply(translateMatrix, rotateMatrix);
//    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, scaleMatrix);

    /*
    // 绕x轴
    transformMatrix = GLKMatrix4Make(1.0, 0.0,           0.0,          0.0,
                                     0.0, cos(elValue), -sin(elValue), 0.0,
                                     0.0, sin(elValue),  cos(elValue), 0.0,
                                     0.0, 0.0,           0.0,          1.0);

    // 绕y轴
    transformMatrix = GLKMatrix4Make(cos(elValue),0.0, sin(elValue), 0.0,
                                     0.0,         1.0, 0.0,          0.0,
                                    -sin(elValue),0.0, cos(elValue), 0.0,
                                     0.0,         0.0, 0.0,          1.0);

    // 绕z轴
    transformMatrix = GLKMatrix4Make(cos(elValue),-sin(elValue), 0.0, 0.0,
                                     sin(elValue), cos(elValue), 0.0, 0.0,
                                     0.0,           0.0,         1.0, 0.0,
                                     0.0,           0.0,         0.0, 1.0);
    */

    return modelViewMatrix;

}

// 在update中修改数据
- (GLKMatrix4)updateModelViewMatrix2 {

   GLKMatrix4 modelViewMatrix =  GLKMatrix4Identity;

    float currentTime =  CMTimeGetSeconds(self.currTime);
    GLfloat elValue = sinf(currentTime);
    NSLog(@"elValue = %lf",elValue);
    // 平移
    GLKMatrix4 translateMatrix2 = GLKMatrix4MakeTranslation(elValue, 0.0, 0.0);

    // 缩放
    GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(elValue, elValue, 1.0);
    modelViewMatrix = GLKMatrix4Multiply(translateMatrix2, scaleMatrix);

    return modelViewMatrix;

//    // 缩放
//    GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(elValue, elValue, 1.0);
//
//    // 旋转
//    GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(elValue , 0.0, 0.0, 1.0);
//
//    // 平移
//    GLKMatrix4 translateMatrix = GLKMatrix4MakeTranslation(elValue, elValue, 0.0);
//
//    //                        平移              旋转           缩放
    // transformMatrix = translateMatrix * rotateMatrix * scaleMatrix
    // 矩阵会按照从右到左的顺序应用到position上。也就是先缩放（scale）,再旋转（rotate）,最后平移（translate）
//    // 如果这个顺序反过来，就完全不同了。从线性代数角度来讲，就是矩阵A乘以矩阵B不等于矩阵B乘以矩阵A。
//    modelViewMatrix = GLKMatrix4Multiply(translateMatrix, rotateMatrix);
//    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, scaleMatrix);

    /*
    // 绕x轴
    transformMatrix = GLKMatrix4Make(1.0, 0.0,           0.0,          0.0,
                                     0.0, cos(elValue), -sin(elValue), 0.0,
                                     0.0, sin(elValue),  cos(elValue), 0.0,
                                     0.0, 0.0,           0.0,          1.0);

    // 绕y轴
    transformMatrix = GLKMatrix4Make(cos(elValue),0.0, sin(elValue), 0.0,
                                     0.0,         1.0, 0.0,          0.0,
                                    -sin(elValue),0.0, cos(elValue), 0.0,
                                     0.0,         0.0, 0.0,          1.0);

    // 绕z轴
    transformMatrix = GLKMatrix4Make(cos(elValue),-sin(elValue), 0.0, 0.0,
                                     sin(elValue), cos(elValue), 0.0, 0.0,
                                     0.0,           0.0,         1.0, 0.0,
                                     0.0,           0.0,         0.0, 1.0);
    */

    return modelViewMatrix;

}



- (void)timeAction {
//    glUseProgram(self.program);
//
//    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);

////     传入时间
//    float currentTime =  [self getTimestamp];
    float currentTime =  CMTimeGetSeconds(self.currTime);
    GLuint time = glGetUniformLocation(self.program, "Time");
//    NSLog(@"currentTime = %lf",currentTime);
    glUniform1f(time, currentTime);

    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);

    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);


}

@end
