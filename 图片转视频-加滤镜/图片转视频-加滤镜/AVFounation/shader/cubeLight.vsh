attribute vec4 Position;
attribute vec2 TextureCoords;
varying vec2 TextureCoordsVarying;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

attribute vec3 a_Normal;

varying lowp vec3 frag_Normal;
varying lowp vec3 frag_Pos;
uniform highp mat4 u_modelMatrix;

void main (void) {

    gl_Position = projectionMatrix * modelViewMatrix * Position;
    TextureCoordsVarying = TextureCoords;
    frag_Normal = vec3(u_modelMatrix * vec4(a_Normal, 0.0));
    frag_Pos = vec3(u_modelMatrix * Position);
}


