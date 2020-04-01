precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {

    vec2 uv = TextureCoordsVarying.xy;
     if(uv.y >= 0.0 && uv.y <= 0.5){
         uv.y = uv.y + 0.25;
     }else{
         uv.y = uv.y - 0.25;
     }

    vec4 mask = texture2D(Texture, uv);
    gl_FragColor = vec4(mask.rgb, 1.0);
}

