#import "MKGPUImageFilter.h"

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
GLfloat kMKColorConversion601Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
GLfloat kMKColorConversion601FullRangeDefault[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

// BT.709, which is the standard for HDTV.
GLfloat kMKColorConversion709Default[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};


GLfloat *kMKColorConversion601 = kMKColorConversion601Default;
GLfloat *kMKColorConversion601FullRange = kMKColorConversion601FullRangeDefault;
GLfloat *kMKColorConversion709 = kMKColorConversion709Default;

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kMKGPUImageYUVVideoRangeConversionForRGFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).rg - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );
#else
NSString *const kMKGPUImageYUVVideoRangeConversionForRGFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 
 void main()
 {
     vec3 yuv;
     vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).rg - vec2(0.5, 0.5);
     
     // BT.601, which is the standard for SDTV is provided as a reference
     /*
      rgb = mat3(      1,       1,       1,
      0, -.39465, 2.03211,
      1.13983, -.58060,       0) * yuv;
      */
     
     // Using BT.709 which is the standard for HDTV
     rgb = mat3(      1,       1,       1,
                0, -.21482, 2.12798,
                1.28033, -.38059,       0) * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );
#endif

NSString *const kMKGPUImageYUVFullRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kMKGPUImageYUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;

     highp vec2 uv = textureCoordinate.xy;
    if(uv.y >= 0.0 && uv.y <= 1.0/3.0){
          uv.y = uv.y + 1.0 / 3.0;
      }else if(uv.y >= 2.0 / 3.0){
          uv.y = uv.y - 1.0/ 3.0 ;
      }
     yuv.x = texture2D(luminanceTexture, uv).r - (16.0/255.0);
     yuv.yz = texture2D(chrominanceTexture, uv).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );
#else
NSString *const kMKGPUImageYUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 
 void main()
 {
     vec3 yuv;
     vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     
     // BT.601, which is the standard for SDTV is provided as a reference
     /*
      rgb = mat3(      1,       1,       1,
      0, -.39465, 2.03211,
      1.13983, -.58060,       0) * yuv;
      */
     
     // Using BT.709 which is the standard for HDTV
     rgb = mat3(      1,       1,       1,
                0, -.21482, 2.12798,
                1.28033, -.38059,       0) * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );
#endif


