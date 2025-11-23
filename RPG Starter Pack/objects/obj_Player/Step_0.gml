// -------------------------
// 1. INPUT (WASD)
// -------------------------
var _hor = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var _ver = keyboard_check(ord("S")) - keyboard_check(ord("W"));

// -------------------------
// 2. FÍSICA (ACELERAÇÃO/FRICÇÃO)
// -------------------------
// Horizontal
if (_hor != 0) hsp = lerp(hsp, _hor * move_speed, accel);
else           hsp = lerp(hsp, 0, friction);

// Vertical
if (_ver != 0) vsp = lerp(vsp, _ver * move_speed, accel);
else           vsp = lerp(vsp, 0, friction);

// Limpeza de "Micro-Movimento" (Evita hsp ficar em 0.00001)
if (abs(hsp) < 0.1) hsp = 0;
if (abs(vsp) < 0.1) vsp = 0;

// -------------------------
// 3. COLISÃO E MOVIMENTO (PREDICTIVE)
// -------------------------
// O segredo para não travar: Verifique onde VAI estar (x + hsp)

// === EIXO X ===
if (place_meeting(x + hsp, y, col_obj)) {
    // Se vai bater, avança pixel por pixel até encostar
    while (!place_meeting(x + sign(hsp), y, col_obj)) {
        x += sign(hsp);
    }
    hsp = 0; // Para a velocidade
}
x += hsp; // Aplica o movimento final

// === EIXO Y ===
if (place_meeting(x, y + vsp, col_obj)) {
    while (!place_meeting(x, y + sign(vsp), col_obj)) {
        y += sign(vsp);
    }
    vsp = 0;
}
y += vsp;

// -------------------------
// 4. ANIMAÇÃO
// -------------------------
// Verifica se está se movendo significativamente
if (hsp != 0 || vsp != 0) {
    // Prioridade para animação vertical (comum em RPG)
    if (vsp > 0) sprite_index = spr_player_walk_down;
    else if (vsp < 0) sprite_index = spr_player_walk_up;
    else if (hsp > 0) sprite_index = spr_player_walk_right;
    else if (hsp < 0) sprite_index = spr_player_walk_left;
} 
else {
    // IDLE: Mantém a direção baseada no último sprite usado
    if (sprite_index == spr_player_walk_right) sprite_index = spr_player_idle_right;
    else if (sprite_index == spr_player_walk_left) sprite_index = spr_player_idle_left;
    else if (sprite_index == spr_player_walk_up) sprite_index = spr_player_idle_up;
    else if (sprite_index == spr_player_walk_down) sprite_index = spr_player_idle_down;
}

// -------------------------
// 5. NETWORKING (SMART UPDATE)
// -------------------------
if (network_timer > 0) network_timer--;

// Detecta mudanças
var _pos_changed = (x != xprevious || y != yprevious);
var _spr_changed = (sprite_index != last_sprite);

// REGRA DE OURO:
// Se mudou o sprite (parou de andar), envia IMEDIATAMENTE (ignora timer).
// Se só andou, respeita o timer (3 frames) para economizar banda.
if (_spr_changed || (_pos_changed && network_timer <= 0)) {
    
    var payload = {
        x: x,
        y: y,
        spr: sprite_index
    };

    if (obj_Network.connected) {
        phoenix_send(obj_Network.socket, "room:lobby", "move", payload);
    }

    last_sprite = sprite_index;
    network_timer = 1; // Reseta o delay (20 updates por segundo)
}