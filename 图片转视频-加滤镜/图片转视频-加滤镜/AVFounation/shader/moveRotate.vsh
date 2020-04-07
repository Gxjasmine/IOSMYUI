attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform mat4 modelViewMatrix;

uniform float Time;

const float PI = 3.1415926;

void main (void) {
    float duration = 1.0;
    float maxAmplitude = 0.7;

    float time = mod(Time, duration);
    float amplitude = 0.3 + maxAmplitude * abs(sin(time * (PI / duration)));
    vec4 vPos;
//    vPos = vec4(Position.x * amplitude, Position.y * amplitude, Position.zw);
//    vPos = Position * modelViewMatrix;
    gl_Position = modelViewMatrix * Position;

    TextureCoordsVarying = TextureCoords;
}


