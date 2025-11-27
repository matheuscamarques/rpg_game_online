/// CONFIGURAÇÃO GERAL
move_speed = 3.2;
accel      = 0.2;
friction   = 0.25;
damage     = 10;

hsp = 0;
vsp = 0;
facing_direction = 270;

// CONFIGURAÇÃO DO ATAQUE (Novo)
attack_duration_max = 20; // O ataque dura 20 frames (aprox 0.3 segundos)
attack_timer = 0;         // Contador regressivo

// Colisão
col_obj = layer_tilemap_get_id("Tiles_col");

// REDE
last_sprite = sprite_index;
network_timer = 0;
xprevious = x;
yprevious = y;

// --- STATE MACHINE ---
enum STATES {
    FREE,
    ATTACK
}
state = STATES.FREE;

// ==========================================================
// MÉTODO 1: FÍSICA (Mantive igual)
// ==========================================================
do_movement_logic = method(self, function() {
    var _hor = keyboard_check(ord("D")) - keyboard_check(ord("A"));
    var _ver = keyboard_check(ord("S")) - keyboard_check(ord("W"));

    if (_hor != 0) hsp = lerp(hsp, _hor * move_speed, accel);
    else           hsp = lerp(hsp, 0, friction);

    if (_ver != 0) vsp = lerp(vsp, _ver * move_speed, accel);
    else           vsp = lerp(vsp, 0, friction);

    if (abs(hsp) < 0.1) hsp = 0;
    if (abs(vsp) < 0.1) vsp = 0;

    if (_hor != 0 || _ver != 0) {
        facing_direction = point_direction(0, 0, _hor, _ver);
    }

    if (place_meeting(x + hsp, y, col_obj)) {
        while (!place_meeting(x + sign(hsp), y, col_obj)) x += sign(hsp);
        hsp = 0;
    }
    x += hsp;

    if (place_meeting(x, y + vsp, col_obj)) {
        while (!place_meeting(x, y + sign(vsp), col_obj)) y += sign(vsp);
        vsp = 0;
    }
    y += vsp;
});

// ==========================================================
// MÉTODO 2: VISUAL / SPRITES (NOVO - Resolve o Moonwalk)
// ==========================================================
// Criamos isso separado para usar TANTO no estado Free quanto no Attack
update_sprites = method(self, function() {
    if (hsp != 0 || vsp != 0) {
        // Se está se movendo, usa sprites de andar
        if (vsp > 0) sprite_index = spr_player_walk_down;
        else if (vsp < 0) sprite_index = spr_player_walk_up;
        else if (hsp > 0) sprite_index = spr_player_walk_right;
        else if (hsp < 0) sprite_index = spr_player_walk_left;
    } else {
        // Se está parado, usa sprites de idle
        if (facing_direction == 0)   sprite_index = spr_player_idle_right;
        if (facing_direction == 90)  sprite_index = spr_player_idle_up;
        if (facing_direction == 180) sprite_index = spr_player_idle_left;
        if (facing_direction == 270) sprite_index = spr_player_idle_down;
    }
});

// ==========================================================
// MÉTODOS DE ESTADO
// ==========================================================

// Lógica de Movimento (Estado FREE)
state_free = method(self, function() {
    do_movement_logic(); // Física
    update_sprites();    // Sprites

    // Trigger de Ataque
    if (keyboard_check_pressed(ord("K"))) {
        state = STATES.ATTACK;
        attack_timer = attack_duration_max; // Inicia o cronômetro do ataque
        // image_blend = c_red; 
    }
});

// Lógica de Combate (Estado ATTACK)
state_attack = method(self, function() {
    do_movement_logic(); // 1. Permite mover (Kiting)
    update_sprites();    // 2. Atualiza animação das pernas (Fim do Moonwalk)
    
    // Diminui o timer
    attack_timer--;

    // 3. SPAWN DA HITBOX (Baseado no Timer, não no frame)
    // Se o timer estiver em 15 (logo no começo), spawna o dano
    if (attack_timer == (attack_duration_max - 5)) { 
        if (!instance_exists(obj_Hitbox)) {
            var _dist = 0; 
            var _spawn_x = x + lengthdir_x(_dist, facing_direction);
            var _spawn_y = y + lengthdir_y(_dist, facing_direction);
            
            var _hitbox = instance_create_layer(_spawn_x, _spawn_y, "Instances", obj_Hitbox);
            _hitbox.owner = id;        
            _hitbox.damage = damage;   
            _hitbox.image_angle = facing_direction;
			_hitbox.is_authoritative = true;
        }
    }
    
    // Atualiza posição da hitbox para acompanhar o player andando
    if (instance_exists(obj_Hitbox)) {
        var _dist = 0;
        obj_Hitbox.x = x + lengthdir_x(_dist, facing_direction);
        obj_Hitbox.y = y + lengthdir_y(_dist, facing_direction);
        obj_Hitbox.image_angle = facing_direction;
    }

    // 4. FIM DO ATAQUE (Quando o timer zerar)
    if (attack_timer <= 0) {
        if (keyboard_check(ord("K"))) {
            // Se segurar botão, REINICIA o ataque
            attack_timer = attack_duration_max;
            if (instance_exists(obj_Hitbox)) instance_destroy(obj_Hitbox);
        } else {
            // Senão, volta ao normal
            state = STATES.FREE;
            image_blend = c_white;
            if (instance_exists(obj_Hitbox)) instance_destroy(obj_Hitbox); // Segurança extra
        }
    }
});




export_map_to_json();






last_state = state;