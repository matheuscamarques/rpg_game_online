// 1. MOVIMENTO SUAVE (INTERPOLAÇÃO)
var _smooth = 0.2;
x = lerp(x, target_x, _smooth);
y = lerp(y, target_y, _smooth);

// 2. RENDERIZAÇÃO
image_speed = 1;
depth = -y;

// NOTA: Removemos o bloco "if string_pos..." porque agora 
// a variável 'facing_direction' é atualizada diretamente pelo script sync_remote_player.

// =========================================================
// 3. GERENCIAMENTO DA HITBOX (COM TIMER E DIREÇÃO REAL)
// =========================================================

if (remote_state == 1) {
    // --- ESTADO: ATACANDO (Servidor mandou state 1) ---

    // A. LÓGICA DE SPAWN (Só cria se o timer zerou)
    // Isso resolve o problema de criar infinitos ataques
    if (attack_timer <= 0) {
        attack_timer = attack_timer_max;
        if (instance_exists(my_hitbox)) instance_destroy(my_hitbox);
        
		var _dist = 0;
        var _spawn_x = x + lengthdir_x(_dist, facing_direction);
        var _spawn_y = y + lengthdir_y(_dist, facing_direction);
        
        my_hitbox = instance_create_layer(_spawn_x, _spawn_y, "Instances", obj_Hitbox);
        my_hitbox.owner = id; 
        my_hitbox.image_angle = facing_direction;
        my_hitbox.damage = 0; 
        
        // --- ESSENCIAL ---
        // Desliga a lógica de rede dessa hitbox. Ela é só um desenho.
        my_hitbox.is_authoritative = false; 
    }

    // B. MANTÉM A HITBOX GRUDADA NO PLAYER
    // Atualiza a posição a cada frame para acompanhar o movimento (caso ele ataque andando)
    if (instance_exists(my_hitbox)) {
        var _dist = 0;
        my_hitbox.x = x + lengthdir_x(_dist, facing_direction);
        my_hitbox.y = y + lengthdir_y(_dist, facing_direction);
        my_hitbox.image_angle = facing_direction;
    }

    // C. CONTAGEM REGRESSIVA DO TEMPO
    // Diminui o timer. Se chegar a 0 e o state continuar 1, ele entra no IF lá em cima e ataca de novo.
    if (attack_timer > 0) {
        attack_timer--;
    }

} 
else {
    // --- ESTADO: LIVRE (0) ---
    
    // Reseta o timer para que, assim que ele atacar de novo, saia instantaneamente
    attack_timer = 0;

    // Se parou de atacar, destrói a hitbox visual imediatamente
    if (instance_exists(my_hitbox)) {
        instance_destroy(my_hitbox);
        my_hitbox = noone;
    }
}