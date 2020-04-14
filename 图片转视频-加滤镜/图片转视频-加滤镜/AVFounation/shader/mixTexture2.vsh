attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform mat4 modelViewMatrix;


void main (void) {

    gl_Position = Position;

    TextureCoordsVarying = TextureCoords;
}

