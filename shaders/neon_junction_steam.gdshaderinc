// Native rolling alley steam. Only the two authored smoke regions use the clean plate.
uniform sampler2D clean_city : source_color, filter_nearest, repeat_disable;
float steam_hash(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float steam_noise(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(steam_hash(i),steam_hash(i+vec2(1,0)),f.x),
        mix(steam_hash(i+vec2(0,1)),steam_hash(i+vec2(1,1)),f.x),f.y);
}
float steam_fbm(vec2 p) {
    return steam_noise(p)*0.57+steam_noise(p*2.03+vec2(14.3,8.1))*0.29
        +steam_noise(p*4.07+vec2(5.7,31.4))*0.14;
}
float steam_box(vec2 p,vec4 bounds,float feather) {
    return smoothstep(bounds.x,bounds.x+feather,p.x)
        *(1.0-smoothstep(bounds.z-feather,bounds.z,p.x))
        *smoothstep(bounds.y,bounds.y+feather,p.y)
        *(1.0-smoothstep(bounds.w-feather,bounds.w,p.y));
}
float steam_foreground(vec2 p) {
    float mask=region(p,vec4(2340.0,0.0,2752.0,853.0));
    mask=max(mask,region(p,vec4(2390.0,853.0,2752.0,963.0)));
    mask=max(mask,region(p,vec4(2375.0,853.0,2400.0,920.0)));
    mask=max(mask,region(p,vec4(2105.0,1326.0,2240.0,1536.0)));
    mask=max(mask,region(p,vec4(2240.0,1341.0,2752.0,1536.0)));
    mask=max(mask,region(p,vec4(2340.0,1065.0,2752.0,1536.0)));
    mask=max(mask,step(1401.0,p.y));
    return mask;
}
float steam_plume(vec2 p,vec2 origin,float height,float wind,float source_width,float seed,float t) {
    float density=0.0;
    // A bounded, deterministic eight-billow stream. Warm start; no empty startup.
    for(int i=0;i<8;i++) {
        float id=float(i);
        float age=fract(t/10.5+id/8.0+seed);
        float wobble=sin(age*6.7+seed*11.0+t*0.31)*(8.0+age*24.0);
        float gust=1.0+0.14*sin(t*0.55+age*1.8);
        vec2 centre=origin+vec2(wind*pow(age,0.72)*gust+wobble,-height*age);
        float radius=mix(52.0,143.0,pow(age,0.75))*(0.88+0.12*sin(id*2.4));
        // Steam rises from a broad source behind the ledge, extending to the right.
        // The source stays broad at birth, then merges into the existing wind-blown cloud.
        vec2 offset=p-centre;
        float spread=source_width*(1.0-age*0.45);
        offset.x-=clamp(offset.x,0.0,spread);
        vec2 delta=offset/vec2(radius,radius*0.83);
        float curl=steam_fbm(p*0.019+vec2(seed*13.0-t*0.42,t*0.62));
        float distance=length(delta)+(curl-0.5)*0.85;
        float body=1.0-smoothstep(0.16,1.13,distance);
        float lifetime=smoothstep(0.0,0.08,age)*(1.0-smoothstep(0.79,1.0,age));
        density+=body*lifetime*0.68;
    }
    return clamp(density,0.0,0.94);
}
vec3 rolling_steam(vec2 uv,vec2 texel,vec3 original,float t) {
    vec2 full_pixel=uv/texel;
    // Cull outside both plumes' maximum travel. These bounds never clip visible billows.
    if(full_pixel.x<1840.0 || full_pixel.y<520.0 || full_pixel.y>1410.0) {
        return original;
    }
    float upper_clean=steam_box(full_pixel,vec4(2120,746,2440,957),14.0);
    float lower_clean=steam_box(full_pixel,vec4(1920,1080,2370,1408),16.0);
    float visible=1.0-steam_foreground(full_pixel);
    float clean_area=max(upper_clean,lower_clean)*visible;
    vec3 base=mix(original,texture(clean_city,uv).rgb,clean_area);
    // The cleanup patch removes old paint; it must NOT crop the moving silhouette.
    vec2 p=floor(full_pixel/3.0)*3.0;
    float high=steam_plume(p,vec2(2233,954),219.0,138.0,95.0,0.17,t);
    float low=steam_plume(p,vec2(2035,1400),314.0,240.0,135.0,0.63,t);
    // Only the physical bridge separates the two alleys. Tops fade by billow lifetime.
    high*=1.0-smoothstep(950.0,957.0,full_pixel.y);
    low*=smoothstep(1078.0,1088.0,full_pixel.y);
    float density=max(high,low)*visible;
    float detail=steam_fbm(p*0.034+vec2(-t*0.48,t*0.81));
    float tone=floor(clamp(detail*0.74+density*0.45,0.0,0.99)*5.0)/4.0;
    vec3 shadow=vec3(0.24,0.24,0.40);
    vec3 light=vec3(0.59,0.57,0.76);
    vec3 vapour=mix(shadow,light,tone);
    vapour+=vec3(0.06,0.0,0.04)*step(1080.0,full_pixel.y);
    return mix(base,vapour,density*0.86);
}
