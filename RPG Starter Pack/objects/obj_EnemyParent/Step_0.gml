// 1. INTERPOLAÇÃO DE MOVIMENTO (Lerp)
var _dist = point_distance(x, y, target_x, target_y);

// Só move se estiver longe (evita tremedeira de pixel)
if (_dist > 1) {
    x = lerp(x, target_x, smoothing);
    y = lerp(y, target_y, smoothing);
    
    // 2. DIREÇÃO VISUAL (Simples)
    // Se estiver indo para direita, inverte o sprite (se necessário)
    if (target_x > x) image_xscale = 1;
    else image_xscale = -1;
    
    // Se você tiver sprites específicos (spr_slime_run), mude aqui
    // sprite_index = spr_slime_run;
} else {
    // sprite_index = spr_slime_idle;
}

// 3. PROFUNDIDADE (Z-Ordering)
depth = -y;