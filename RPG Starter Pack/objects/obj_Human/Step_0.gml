// 1. MOVIMENTO SUAVE (Herdado)
var _dist = point_distance(x, y, target_x, target_y);
if (_dist > 1) {
    x = lerp(x, target_x, 0.1);
    y = lerp(y, target_y, 0.1);
}
depth = -y;

// =========================================================
// 2. MÁQUINA DE ESTADOS VISUAL
// =========================================================

if (remote_state == 1) {
    // --- ESTADO: ATACANDO ---
    
    // 1. Define o sprite como IDLE (Parado) na direção do ataque
    // Como não tem animação de ataque, ele "para" para bater.
    set_sprite_direction(facing_direction, false); 
    
    // 2. LÓGICA DE HITBOX (Spawna o corte)
    if (attack_timer <= 0) {
        attack_timer = attack_timer_max;
        
        if (instance_exists(my_hitbox)) instance_destroy(my_hitbox);
        
        // Cria Hitbox Visual
		var _dist_hitbox = 0;
        var _spawn_x = x + lengthdir_x(_dist_hitbox, facing_direction);
        var _spawn_y = y + lengthdir_y(_dist_hitbox, facing_direction);
        
        my_hitbox = instance_create_layer(_spawn_x, _spawn_y, "Instances", obj_Hitbox);
        my_hitbox.owner = id;
        my_hitbox.image_angle = facing_direction;
        my_hitbox.damage = 0;
        my_hitbox.is_authoritative = false; // Apenas visual!
    }
    
    if (attack_timer > 0) attack_timer--;
} 
else {
    // --- ESTADO: LIVRE (ANDANDO/IDLE) ---
    attack_timer = 0;
    if (instance_exists(my_hitbox)) instance_destroy(my_hitbox);

    // Seleção de Sprite
    if (_dist > 2) {
        // Se está movendo, usa sprites de WALK
        // Calcula a direção baseado no movimento para atualizar o visual
        var _move_dir = point_direction(x, y, target_x, target_y);
        set_sprite_direction(_move_dir, true);
    } else {
        // Se parou, usa sprites de IDLE (mantendo a última direção válida do facing)
        set_sprite_direction(facing_direction, false);
    }
}