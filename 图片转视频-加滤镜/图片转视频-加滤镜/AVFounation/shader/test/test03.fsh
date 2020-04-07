precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;
uniform float alpha;

void main (void) {
    vec4 mask = texture2D(Texture, TextureCoordsVarying);
    gl_FragColor = mask * alpha;
}

