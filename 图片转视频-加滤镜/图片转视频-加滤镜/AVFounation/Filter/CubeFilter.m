//
//  CubeFilter.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/7.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "CubeFilter.h"
#import <GLKit/GLKit.h>
#import "GLESMath.h"

typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;

@interface CubeFilter()
@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存
@property (nonatomic, assign) GLuint textureID; // 纹理 ID
@property (nonatomic, assign) SenceVertex *vertices;

@property (nonatomic, assign) NSTimeInterval startTimeInterval; // 开始的时间戳

@property (nonatomic, assign) BOOL isStartRender; // 开始的时间戳

@end
@implementation CubeFilter

#pragma mark - Public
-(instancetype)init{
    if (self = [super init]) {


    }
    return self;
}
- (CVPixelBufferRef)outputPixelBuffer {
    if (!self.pixelBuffer) {
        return nil;
    }
    self.isStartRender = YES;
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


//        [GPUImageContext setActiveShaderProgram:nil];
//        GPUImageTextureInput *textureInput = [[GPUImageTextureInput alloc] initWithTexture:textureID size:size];
//        GPUImageGlassSphereFilter *filter = [[GPUImageGlassSphereFilter alloc] init];
//        [textureInput addTarget:filter];
//        GPUImageTextureOutput *textureOutput = [[GPUImageTextureOutput alloc] init];
//        [filter addTarget:textureOutput];
//        [textureInput processTextureWithFrameTime:kCMTimeZero];
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


    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);

//    self.program = [MFShaderHelper programWithShaderName:@"shader2"];
    self.program = [MFShaderHelper programWithShaderName:@"cube"];

    glUseProgram(self.program);

    GLuint positionSlot = glGetAttribLocation(self.program, "Position");//位置
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");//纹理
    GLuint textureCoordsSlot = glGetAttribLocation(self.program, "TextureCoords");//纹理坐标

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glUniform1i(textureSlot, 0);


    //8.创建顶点数组 & 索引数组
    //(1)顶点数组 前3顶点值（x,y,z），后3位颜色值(RGB)
    GLfloat attrArr[] =
    {
        -0.5f, 0.5f, 0.0f,  0.0f, 1.0f,//左上
        0.5f, 0.5f, 0.0f,   1.0f, 1.0f,//右上
        -0.5f, -0.5f, 0.0f, 0.0f, 0.0f,//左下
        0.5f, -0.5f, 0.0f,  1.0f, 0.0f,//右下

        0.0f, 0.0f, 1.0f,   0.5f, 0.5f,//顶点
    };



    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_DYNAMIC_DRAW);
    self.vertexBuffer = vertexBuffer; // 将顶点缓存保存，退出时才释放


    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, NULL);

    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float *)NULL + 3);

    GLuint projectionMatrixSlot = glGetUniformLocation(self.program, "projectionMatrix");
    GLuint modelViewMatrixSlot = glGetUniformLocation(self.program, "modelViewMatrix");

    //12.创建4 * 4投影矩阵
       KSMatrix4 _projectionMatrix;
       //(1)获取单元矩阵
       ksMatrixLoadIdentity(&_projectionMatrix);
       //(2)计算纵横比例 = 长/宽
      float width = [UIScreen mainScreen].bounds.size.width;
      float height = [UIScreen mainScreen].bounds.size.height;
       float aspect = width / height; //长宽比
       //(3)获取透视矩阵
       /*
        参数1：矩阵
        参数2：视角，度数为单位
        参数3：纵横比
        参数4：近平面距离
        参数5：远平面距离
        参考PPT
        */
       ksPerspective(&_projectionMatrix, 30.0, aspect, 5.0f, 20.0f); //透视变换，视角30°
       //(4)将投影矩阵传递到顶点着色器
       /*
        void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
        参数列表：
        location:指要更改的uniform变量的位置
        count:更改矩阵的个数
        transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
        value:执行count个元素的指针，用来更新指定uniform变量
        */
       glUniformMatrix4fv(projectionMatrixSlot, 1, GL_FALSE, (GLfloat*)&_projectionMatrix.m[0][0]);


       //13.创建一个4 * 4 矩阵，模型视图矩阵
       KSMatrix4 _modelViewMatrix;
       //(1)获取单元矩阵
       ksMatrixLoadIdentity(&_modelViewMatrix);
       //(2)平移，z轴平移-10
       ksTranslate(&_modelViewMatrix, 0.0, 0.0, -10.0);
       //(3)创建一个4 * 4 矩阵，旋转矩阵
       KSMatrix4 _rotationMatrix;
       //(4)初始化为单元矩阵
       ksMatrixLoadIdentity(&_rotationMatrix);
       //(5)旋转
       ksRotate(&_rotationMatrix, 20, 0.0, 0.0, 1.0); //绕Z轴
       ksRotate(&_rotationMatrix, 20, 1.0, 0.0, 0.0); //绕x轴

       //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
        ksMatrixMultiply(&_modelViewMatrix, &_rotationMatrix, &_modelViewMatrix);
       //(7)将模型视图矩阵传递到顶点着色器
       /*
        void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
        参数列表：
        location:指要更改的uniform变量的位置
        count:更改矩阵的个数
        transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
        value:执行count个元素的指针，用来更新指定uniform变量
        */
       glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&_modelViewMatrix.m[0][0]);


       //14.开启剔除操作效果
       glEnable(GL_CULL_FACE);

    [self timeAction];

}

- (void)timeAction {
//    glUseProgram(self.program);
//
//    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);

////     传入时间
//    float currentTime =  [self getTimestamp];
    float currentTime =  CMTimeGetSeconds(self.currTime);


    //(2).索引数组
      GLuint indices[] =
      {
          0, 3, 2,
              0, 1, 3,
              0, 2, 4,
              0, 4, 1,
              2, 3, 4,
              1, 4, 3,
      };
    // 重绘
    glDrawElements(GL_TRIANGLES, sizeof(indices) / sizeof(indices[0]), GL_UNSIGNED_INT, indices);


}

@end
