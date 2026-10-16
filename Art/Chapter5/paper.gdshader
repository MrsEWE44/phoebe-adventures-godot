shader_type canvas_item;
uniform bool remove_white=false;
uniform bool grayscale=false;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){vec4 c=texture(TEXTURE,UV);if(remove_white){float w=min(c.r,min(c.g,c.b));c.a*=1.0-smoothstep(.96,.995,w);}if(grayscale){c.rgb=vec3(dot(c.rgb,vec3(.299,.587,.114)));}COLOR=c*tint;}