attribute vec4 Position;
attribute vec2 TextureCoords;
varying lowp vec2 TextureCoordsVarying;

void main()
{
    TextureCoordsVarying = TextureCoords;
    gl_Position = Position;
}
