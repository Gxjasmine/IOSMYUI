precision highp float;

uniform sampler2D Texture0;
uniform sampler2D Texture1;

varying vec2 TextureCoordsVarying;

void main (void) {
    vec4 mask = texture2D(Texture0, TextureCoordsVarying);
    vec4 mask2 = texture2D(Texture1, TextureCoordsVarying);
    gl_FragColor = mask + mask2;

   // gl_FragColor = vec4(mask.rgb, 0.7) + vec4(mask2.rgb, 0.3);
}
