shader_type canvas_item;
render_mode unshaded;
uniform float animation_time = 0.0;
uniform bool animate_signs = true;
uniform bool night_sky_enabled = true;
uniform bool smoke_motion_enabled = true;
uniform sampler2D skyline_height : filter_nearest, repeat_disable;

float region(vec2 p, vec4 r) {
    return step(r.x,p.x)*step(r.y,p.y)*step(p.x,r.z)*step(p.y,r.w);
}
float dip(float t, float period, float offset) {
    float phase = mod(t + offset, period);
    return 1.0 - 0.70 * (1.0 - smoothstep(0.10,0.28,phase));
}
// Lady sign loses power, makes four uneven restart attempts, then recovers.
float faulty_club(float t) {
    float phase=mod(t+14.3,17.8);
    if(phase>=2.08) { return 1.0; }
    float sparks=0.50*step(0.96,phase)*(1.0-step(1.025,phase));
    sparks+=0.88*step(1.10,phase)*(1.0-step(1.17,phase));
    sparks+=0.35*step(1.25,phase)*(1.0-step(1.30,phase));
    sparks+=0.95*step(1.42,phase)*(1.0-step(1.52,phase));
    float recovery=smoothstep(1.69,2.08,phase);
    return clamp(0.035+sparks+0.965*recovery,0.035,1.0);
}
float background_blink(float t,float period,float offset,float hold) {
    float phase=mod(t+offset,period);
    return 0.22+0.78*smoothstep(hold,hold+0.13,phase);
}
float beacon_pulse(float phase) {
    return 1.0 - smoothstep(0.08,0.23,phase);
}
vec3 aircraft_light(vec2 pixel, vec2 position, vec3 hue, float pulse, float size) {
    vec2 d = abs(pixel - floor(position));
    float distance = max(d.x,d.y);
    if (distance > size + 4.0) { return vec3(0.0); }
    float core = 1.0 - step(size,distance);
    float halo = (1.0 - smoothstep(size,size+4.0,distance)) * 0.10;
    float roof_y = texture(skyline_height,vec2(position.x/2752.0,0.5)).r * 1536.0;
    // The same skyline used for grading hides the lights behind city towers.
    float clear_sky = smoothstep(3.0,10.0,roof_y-position.y);
    return hue * (core+halo) * pulse * clear_sky;
}
// Independent flight lanes: source-pixel positions, signed speeds and staggered strobes.
vec3 flight(vec2 pixel, float t, vec4 lane, vec3 hue, float period, float phase, float strength) {
    vec2 position = vec2(600.0 + mod(lane.x + t * lane.z,1600.0),lane.y);
    float pulse = beacon_pulse(mod(t + phase,period));
    return aircraft_light(pixel,position,hue,(0.38 + pulse * 0.64) * strength,lane.w);
}
#include "res://shaders/neon_junction_steam.gdshaderinc"
void fragment() {
    vec4 source = texture(TEXTURE,UV);
    vec3 colour = source.rgb;
    if (animate_signs && smoke_motion_enabled) {
        colour = rolling_steam(UV,TEXTURE_PIXEL_SIZE,colour,animation_time);
    }
    vec3 aircraft = vec3(0.0);
    if (night_sky_enabled) {
        float roof_y = texture(skyline_height,vec2(UV.x,0.5)).r;
        float sky = 1.0 - smoothstep(roof_y-0.010,roof_y,UV.y);
        sky *= step(0.001,roof_y);
        // Keep the existing magenta roof warning lights outside the sky grade.
        float roof_light = smoothstep(0.04,0.18,min(source.r,source.b)-source.g);
        sky *= 1.0 - roof_light;
        // Grade falls away into the existing purple light-pollution haze.
        float grade = sky * (1.0-smoothstep(0.06,0.42,UV.y));
        vec2 offset = TEXTURE_PIXEL_SIZE * 7.0;
        vec3 nearby = (texture(TEXTURE,UV+vec2(offset.x,0.0)).rgb
                    + texture(TEXTURE,UV-vec2(offset.x,0.0)).rgb
                    + texture(TEXTURE,UV+vec2(0.0,offset.y)).rgb
                    + texture(TEXTURE,UV-vec2(0.0,offset.y)).rgb) * 0.25;
        float speck = smoothstep(0.025,0.065,min(source.g-nearby.g,source.b-nearby.b));
        colour = mix(colour,nearby,speck*sky*0.88);
        colour *= mix(vec3(1.0),vec3(0.68,0.72,0.79),grade);
        if (animate_signs) {
            vec2 pixel = floor(UV/TEXTURE_PIXEL_SIZE);
            float t = animation_time;
            aircraft += flight(pixel,t,vec4(520.0,213.0,9.0,2.5),vec3(0.90,0.19,0.25),2.70,1.40,1.0);
            aircraft += flight(pixel,t,vec4(1270.0,286.0,-11.5,2.5),vec3(0.70,0.85,1.0),2.60,1.15,1.0);
            aircraft += flight(pixel,t,vec4(825.0,95.0,4.0,2.5),vec3(0.65,0.76,0.89),3.80,3.10,0.65);
            aircraft += flight(pixel,t,vec4(450.0,65.0,-5.5,2.5),vec3(0.90,0.29,0.32),3.10,0.30,0.70);
            aircraft += flight(pixel,t,vec4(625.0,142.0,-7.0,2.5),vec3(0.77,0.88,1.0),2.30,1.60,0.85);
            aircraft += flight(pixel,t,vec4(960.0,176.0,8.5,2.5),vec3(0.95,0.26,0.30),2.90,0.85,0.90);
            aircraft += flight(pixel,t,vec4(1010.0,52.0,-4.5,2.5),vec3(0.75,0.83,0.94),4.20,2.10,0.65);
            aircraft += flight(pixel,t,vec4(700.0,263.0,13.0,2.5),vec3(0.82,0.90,1.0),1.90,0.50,1.0);
            aircraft += flight(pixel,t,vec4(870.0,327.0,-15.0,2.5),vec3(0.95,0.22,0.28),2.10,1.75,1.0);
            aircraft += flight(pixel,t,vec4(470.0,376.0,17.0,2.5),vec3(0.80,0.89,1.0),2.40,0.15,1.0);
            aircraft += flight(pixel,t,vec4(130.0,126.0,7.5,2.5),vec3(0.95,0.31,0.34),3.30,2.65,0.85);
            aircraft += flight(pixel,t,vec4(1540.0,89.0,-6.0,2.5),vec3(0.72,0.84,1.0),3.60,1.95,0.80);
            // Slower, fainter distant traffic: the city's substitute for a star field.
            aircraft += flight(pixel,t,vec4(450.0,28.0,2.8,1.5),vec3(0.78,0.86,1.0),4.70,0.70,0.76);
            aircraft += flight(pixel,t,vec4(602.0,63.0,-3.1,1.5),vec3(0.86,0.83,0.78),5.10,3.40,0.78);
            aircraft += flight(pixel,t,vec4(710.0,34.0,2.2,1.5),vec3(0.77,0.85,0.99),4.10,2.30,0.72);
            aircraft += flight(pixel,t,vec4(940.0,111.0,-3.8,1.5),vec3(0.78,0.87,1.0),3.90,0.20,0.82);
            aircraft += flight(pixel,t,vec4(1085.0,235.0,5.2,1.5),vec3(0.90,0.40,0.44),3.70,2.80,0.88);
            aircraft += flight(pixel,t,vec4(540.0,304.0,-4.3,1.5),vec3(0.74,0.85,1.0),4.30,1.00,0.86);
            aircraft += flight(pixel,t,vec4(730.0,419.0,3.7,1.5),vec3(0.87,0.81,0.73),5.70,4.45,0.86);
            aircraft += flight(pixel,t,vec4(828.0,467.0,-2.6,1.5),vec3(0.75,0.83,0.96),4.90,2.05,0.80);
            aircraft += flight(pixel,t,vec4(945.0,353.0,4.8,1.5),vec3(0.78,0.85,1.0),3.50,1.35,0.88);
            aircraft += flight(pixel,t,vec4(594.0,194.0,3.3,1.5),vec3(0.90,0.39,0.44),4.50,3.80,0.85);
            aircraft += flight(pixel,t,vec4(1000.0,295.0,-5.6,1.5),vec3(0.76,0.84,1.0),3.20,0.65,0.86);
            aircraft += flight(pixel,t,vec4(1295.0,240.0,-4.1,1.5),vec3(0.80,0.87,1.0),4.60,2.60,0.78);
            aircraft *= sky;
        }
    }
    float lit = 1.0;
    if (animate_signs) {
        float club = region(UV,vec4(0.0327,0.1921,0.1090,0.4622));
        float face = region(UV,vec4(0.812,0.232,0.858,0.371));
        float pixl = region(UV,vec4(0.845,0.683,0.904,0.888));
        float magenta = smoothstep(0.10,0.42,min(source.r,source.b)-source.g);
        float cyan = smoothstep(0.10,0.42,min(source.g,source.b)-source.r);
        lit -= club*magenta*(1.0-faulty_club(animation_time));
        // Four deeper signs; local colour masks exclude their walls and windows.
        float nyvo=region(UV,vec4(0.176,0.124,0.225,0.180));
        float zuix=region(UV,vec4(0.230,0.288,0.258,0.402));
        float koru=region(UV,vec4(0.710,0.135,0.799,0.359));
        float distant_cross=region(UV,vec4(0.404,0.512,0.429,0.559));
        lit -= nyvo*cyan*(1.0-background_blink(animation_time,8.9,7.7,0.22));
        lit -= zuix*magenta*(1.0-background_blink(animation_time,12.4,6.6,0.14));
        lit -= koru*magenta*(1.0-background_blink(animation_time,15.7,6.2,0.30));
        lit -= distant_cross*magenta*(1.0-background_blink(animation_time,10.6,7.7,0.16));
        lit -= face*cyan*(1.0-dip(animation_time,13.3,7.0));
        lit -= pixl*magenta*(1.0-dip(animation_time,17.9,11.0));
    }
    COLOR = vec4(colour * lit + aircraft,source.a);
}
