precision highp float;

uniform sampler2D Texture0;
uniform sampler2D Texture1;

varying vec2 TextureCoordsVarying;

uniform float Time;

const float PI = 3.1415926;

void main (void) {

    float duration = 5.0;
    float maxAmplitude = 0.3;

    float time = mod(Time, duration);
    float amplitude = 1.0 - maxAmplitude / duration * time;
    vec2 uv = vec2(TextureCoordsVarying.x * amplitude, TextureCoordsVarying.y * amplitude);


    vec4 mask = texture2D(Texture0, uv);
    vec4 mask2 = texture2D(Texture1, TextureCoordsVarying);
    gl_FragColor = mask + mask2;

   // gl_FragColor = vec4(mask.rgb, 0.7) + vec4(mask2.rgb, 0.3);
}
