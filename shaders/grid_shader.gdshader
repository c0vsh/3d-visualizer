shader_type spatial;

// Параметры сетки
uniform vec4 grid_color : source_color = vec4(0.5, 0.5, 0.5, 0.1);
uniform float grid_size : hint_range(0.0, 10.0) = 1.0;
uniform float line_width : hint_range(0.01, 0.5) = 0.05;

// Параметры затухания по дальности
uniform float fade_start : hint_range(0.0, 1000.0) = 20.0;
uniform float fade_end   : hint_range(0.0, 1000.0) = 50.0;

void fragment() {
    // Мировые координаты точки
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Координаты камеры в мировом пространстве
    vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float dist = distance(world_pos, camera_pos);
    
    // Расчёт интенсивности линии
    vec2 grid_pos = mod(world_pos.xz, grid_size);
    float dist_x = min(grid_pos.x, grid_size - grid_pos.x);
    float dist_z = min(grid_pos.y, grid_size - grid_pos.y);
    
    float grid_x = 1.0 - smoothstep(0.0, line_width, dist_x);
    float grid_z = 1.0 - smoothstep(0.0, line_width, dist_z);
    float grid_intensity = max(grid_x, grid_z);
    
    // Затухание по дальности (1 – близко, 0 – далеко)
    float fade = 1.0 - smoothstep(fade_start, fade_end, dist);
    
    // Итоговый цвет и прозрачность
    ALBEDO = grid_color.rgb;
    ALPHA = grid_intensity * grid_color.a * fade;
    ALPHA_SCISSOR_THRESHOLD = 0.1;
}