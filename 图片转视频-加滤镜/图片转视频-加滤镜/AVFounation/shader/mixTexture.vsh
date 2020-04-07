attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform mat4 modelViewMatrix;

uniform float Time;

const float PI = 3.1415926;

void main (void) {

    gl_Position = Position;

    TextureCoordsVarying = TextureCoords;
}

