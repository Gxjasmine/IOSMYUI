
//
//  TestViewController.m
//  图片转视频-加滤镜
//
//  Created by fuzhongw on 2020/4/2.
//  Copyright © 2020 fuzhongw. All rights reserved.
//

#import "TestViewController.h"
#import <GLKit/GLKit.h>
#import <CoreMedia/CoreMedia.h>
#import "GLESMath.h"

typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;
@interface TestViewController ()

@property (nonatomic, assign) SenceVertex *vertices;
@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, strong) CADisplayLink *displayLink; // 用于刷新屏幕
@property (nonatomic, assign) NSTimeInterval startTimeInterval; // 开始的时间戳

@property (nonatomic, assign) GLuint program; // 着色器程序
@property (nonatomic, assign) GLuint vertexBuffer; // 顶点缓存
@property (nonatomic, assign) GLuint textureID; // 纹理 ID

@property (nonatomic, assign)  CGFloat currentTime;

@property (nonatomic, assign)  BOOL isModel;

@property (nonatomic, assign)  int tag;
 @property (nonatomic, assign) KSMatrix4 kmodelViewMatrix;
@end

@implementation TestViewController


- (void)dealloc {
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];

      [self commonInit];

      [self startFilerAnimation];
}

- (void)commonInit {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];

    self.vertices = malloc(sizeof(SenceVertex) * 4);

    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};

    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    layer.contentsScale = [[UIScreen mainScreen] scale];

    [self.view.layer addSublayer:layer];
    [self bindRenderLayer:layer];

//    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"sample.jpg"];
    UIImage *image = [UIImage imageNamed:@"7"];
    GLuint textureID = [self createTextureWithImage:image];
    self.textureID = textureID;  // 将纹理 ID 保存，方便后面切换滤镜的时候重用

    glViewport(0, 0, self.drawableWidth, self.drawableHeight);

    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);

    [self setupVertigoShaderProgram]; // 一开始选用默认的着色器

    self.vertexBuffer = vertexBuffer; // 将顶点缓存保存，退出时才释放
}

- (void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer {
    GLuint renderBuffer;
    GLuint frameBuffer;

    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];

    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              renderBuffer);
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


- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);

    return backingWidth;
}

- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);

    return backingHeight;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 移除 displayLink
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

// 开始一个滤镜动画
- (void)startFilerAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    self.startTimeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];

}

- (void)timeAction {
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = self.displayLink.timestamp;
    }

    glUseProgram(self.program);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);

    // 传入时间
    CGFloat currentTime = self.displayLink.timestamp - self.startTimeInterval;
    GLuint time = glGetUniformLocation(self.program, "Time");
//    NSLog(@"currentTime = %lf",currentTime);
    glUniform1f(time, currentTime);

    self.currentTime = currentTime;
    //旋转
    if (_isModel) {

        GLuint modelViewMatrixSlot = glGetUniformLocation(self.program, "modelViewMatrix");
        if (self.tag == 1) {
            
            //GLKIT
            GLKMatrix4 modelViewMatrix = [self updateModelViewMatrix];
            glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)modelViewMatrix.m);
        }
        
        if (self.tag == 2) {
            
            //自定义
            KSMatrix4 modelViewMatrix = [self updateModelViewMatrix2];
            glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&modelViewMatrix.m[0][0]);
        }


          if (self.tag == 3) {

              //自定义
              KSMatrix4 modelViewMatrix = [self updateModelViewMatrix3];
              glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&modelViewMatrix.m[0][0]);
          }

        if (self.tag == 4) {

            //自定义
            KSMatrix4 modelViewMatrix = [self updateModelViewMatrix4];
            glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&modelViewMatrix.m[0][0]);
        }

        if (self.tag == 5) {

            //自定义
            KSMatrix4 modelViewMatrix = [self updateModelViewMatrix5];
            glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&modelViewMatrix.m[0][0]);
        }

    }

    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0, 0, 0, 0.5);

    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

// 在update中修改数据
- (KSMatrix4)updateModelViewMatrix5 {

    float totalTime = 6;
    float currentTime =  self.currentTime;
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
    float currentTime =  self.currentTime;
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

- (KSMatrix4)updateModelViewMatrix3 {


    float totalTime = 5;
    float startRotateValue = 6;

   //13.创建一个4 * 4 矩阵，模型视图矩阵
   KSMatrix4 modelViewMatrix;
   //(1)获取单元矩阵
   ksMatrixLoadIdentity(&modelViewMatrix);

    float currentTime =  self.currentTime;

    float duration5 = fmodf(currentTime, totalTime);
    ksScale(&modelViewMatrix, 0.8, 0.85, 1.0);

    if (duration5 <= totalTime) {


        if (duration5 <=0.5) {

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            GLfloat elValue =  -2 + 4 * duration5;

            // 平移
            //(2)平移，z轴平移-10
            ksTranslate(&slateionMatrix, elValue, elValue,0.0);
            //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);

            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            ksRotate(&_rotationMatrix, startRotateValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);


        }else if (duration5 <= 4.5){

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);
            GLfloat elValue = 0.1 * sinf(duration5);

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
//            GLfloat rotateValue =  2 * sinf(M_PI_2 * (1 + x)) + startRotateValue;
            GLfloat rotateValue =  -2 * sinf(duration5) + startRotateValue;

            ksRotate(&_rotationMatrix, rotateValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);
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
        }

    }

    return modelViewMatrix ;
}

- (KSMatrix4)updateModelViewMatrix2 {


    float totalTime = 5;
    float startRotateValue = 6;

   //13.创建一个4 * 4 矩阵，模型视图矩阵
   KSMatrix4 modelViewMatrix;
   //(1)获取单元矩阵
   ksMatrixLoadIdentity(&modelViewMatrix);

    float currentTime =  self.currentTime;

    float duration5 = fmodf(currentTime, totalTime);
    ksScale(&modelViewMatrix, 0.8, 0.85, 1.0);

    if (duration5 <= totalTime) {


        if (duration5 <=2) {

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            GLfloat elValue =  -2 + tan(M_PI / 4.0) * duration5;

            // 平移
            //(2)平移，z轴平移-10
            ksTranslate(&slateionMatrix, elValue, elValue,0.0);
            //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);

            //(3)创建一个4 * 4 矩阵，旋转矩阵
            KSMatrix4 _rotationMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&_rotationMatrix);
            //(5)旋转
            ksRotate(&_rotationMatrix, startRotateValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);


        }else if (duration5 <= 4.5){

            //(3)创建一个4 * 4 矩阵，缩放矩阵
            KSMatrix4 slateionMatrix;
            //(4)初始化为单元矩阵
            ksMatrixLoadIdentity(&slateionMatrix);

            float x = duration5 - 2;

            float yValue = 0;
            GLfloat lastyValue =  -2 + tan(M_PI / 4.0) * 2.0;
             yValue += lastyValue;

            GLfloat elValue =  0.1 * sinf(M_PI_2 * (1 + x));
            
//            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);
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
            GLfloat rotateValue =  2 * sinf(M_PI_2 * (1 + x)) + startRotateValue;

            ksRotate(&_rotationMatrix, rotateValue, 0.0, 0.0, 1.0); //绕Z轴
            ksMatrixMultiply(&modelViewMatrix, &_rotationMatrix, &modelViewMatrix);
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
            NSLog(@"ss = %lf",ss);

            GLfloat elValue =  2 + -tan(M_PI / 3.0) * ss;
//            NSLog(@"currentTime = %lf,fmodf = %lf",duration5,elValue);

            // 平移
            ksTranslate(&slateionMatrix, elValue, elValue,0.0);
            ksMatrixMultiply(&modelViewMatrix, &slateionMatrix, &modelViewMatrix);
        }

    }

    return modelViewMatrix ;
}

- (GLKMatrix4)updateModelViewMatrix {

   GLKMatrix4 modelViewMatrix =  GLKMatrix4Identity;

    float currentTime =  self.currentTime;

    float duration5 = fmodf(currentTime, 5.0);


    if (duration5 <= 5) {

        if (duration5 <= 2) {
            // 缩放
//            GLfloat elValue =   0.8 * fabs(sinf(duration5)) + 0.2;
            GLfloat elValue =   0.4 * duration5 + 0.2;

            GLKMatrix4 scaleMatrix = GLKMatrix4MakeScale(elValue, elValue, 1.0);
            
            modelViewMatrix = GLKMatrix4Multiply(scaleMatrix, modelViewMatrix);

            // 旋转
            GLfloat rotex =   0.4 - duration5 * 0.2;
//            NSLog(@"duration5 = %lf,elValue = %lf m rotex =%lf",duration5,elValue,rotex);

            GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(rotex , 0.0, 0.0, 1.0);
            modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotateMatrix);

        }else {

            // 旋转d
            GLfloat rotex =   0.2 * sinf(duration5);

            if (duration5 <= 4){

                GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(rotex , 0.0, 0.0, 1.0);
                modelViewMatrix = GLKMatrix4Multiply(rotateMatrix, modelViewMatrix);

            }else{

                GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(rotex , 0.0, 0.0, 1.0);
                             modelViewMatrix = GLKMatrix4Multiply(rotateMatrix, modelViewMatrix);
                float d = tan(M_PI / 2.8) * (duration5 - 4) * 2;
                NSLog(@"currentTime = %lf,fmodf = %lf",duration5,d);
                // 平移
                GLKMatrix4 translateMatrix = GLKMatrix4MakeTranslation(d, d, 0.0);
                modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, translateMatrix);
            }


        }
        
        
        
//        float d = fmodf(duration5, 5.0);
//        NSLog(@"currentTime = %lf,fmodf = %lf",duration5,d);
//
//        // 平移
//        GLKMatrix4 translateMatrix2 = GLKMatrix4MakeTranslation(d, 0.0, 0.0);
        
        
        //    // 旋转
        //    GLKMatrix4 rotateMatrix = GLKMatrix4MakeRotation(elValue , 0.0, 0.0, 1.0);

//        modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, translateMatrix2);
        //    modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotateMatrix);
    }


    return modelViewMatrix;
}

- (IBAction)onclickButton:(UIButton *)sender {

    self.tag  = (int)sender.tag;
    NSString *str = nil;

    if (sender.tag == 1 || sender.tag == 2 || sender.tag == 3 || sender.tag == 4) {
        self.isModel = YES;
        str = [NSString stringWithFormat:@"test02"];

    }else{
        self.isModel = NO;
      str = [NSString stringWithFormat:@"test0%ld",sender.tag + 1];

    }

    if (sender.tag == 5) {
        self.isModel = YES;
        str = [NSString stringWithFormat:@"test03"];

    }

    [self setupShaderProgramWithName:str];

}

- (void)setupVertigoShaderProgram {
    [self setupShaderProgramWithName:@"test01"];
}

// 初始化着色器程序
- (void)setupShaderProgramWithName:(NSString *)name {
    GLuint program = [self programWithShaderName:name];
    glUseProgram(program);

    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    glUniform1i(textureSlot, 0);

    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));

    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));

    self.program = program;
}

- (GLuint)programWithShaderName:(NSString *)shaderName {
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];

    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);

    glLinkProgram(program);

    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    return program;
}


- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }

    GLuint shader = glCreateShader(shaderType);

    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);

    glCompileShader(shader);

    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }

    return shader;
}
@end
