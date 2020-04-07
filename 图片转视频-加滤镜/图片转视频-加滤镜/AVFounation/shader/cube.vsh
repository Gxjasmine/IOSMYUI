attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform float Time;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;


void main (void) {

    gl_Position = projectionMatrix * modelViewMatrix * Position;
    TextureCoordsVarying = TextureCoords;
}


