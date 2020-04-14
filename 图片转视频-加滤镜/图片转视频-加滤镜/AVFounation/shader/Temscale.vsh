attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform float Time;

const float PI = 3.1415926;

void main (void) {
    float duration = 5.0;
    float maxAmplitude = 1.0;
    
    float time = mod(Time, duration);
    float amplitude = 0.3 + maxAmplitude * abs(sin(time * (PI / duration)));
    
    gl_Position = vec4(Position.x * amplitude, Position.y * amplitude, Position.zw);
    TextureCoordsVarying = TextureCoords;
}


