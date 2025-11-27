event_inherited(); // Herda variáveis do obj_EnemyParent (interpolação, etc)

// --- CONFIGURAÇÃO DE SPRITES ---
// Mapeamos os sprites disponíveis
spr_idle_d = spr_player_idle_down;
spr_idle_u = spr_player_idle_up;
spr_idle_l = spr_player_idle_left;
spr_idle_r = spr_player_idle_right;

spr_walk_d = spr_player_walk_down;
spr_walk_u = spr_player_walk_up;
spr_walk_l = spr_player_walk_left;
spr_walk_r = spr_player_walk_right;

// --- ESTADO ---
remote_state = 0;      // 0=Free, 1=Attack
facing_direction = 270; // 0=Dir, 90=Cima, 180=Esq, 270=Baixo

// --- COMBATE ---
my_hitbox = noone;
attack_timer = 0;
attack_timer_max = 20; // Tempo entre spawns de hitbox

/// @function set_sprite_direction(angle, is_walking)
set_sprite_direction = method(self, function(_angle, _is_walking) {
    
    // Normaliza o ângulo (garante que fique entre 0 e 360)
    _angle = (_angle + 360) % 360;
    
    // Define qual conjunto de sprites usar
    var _s_down, _s_up, _s_left, _s_right;
    
    if (_is_walking) {
        _s_down = spr_walk_d; _s_up = spr_walk_u; _s_left = spr_walk_l; _s_right = spr_walk_r;
    } else {
        _s_down = spr_idle_d; _s_up = spr_idle_u; _s_left = spr_idle_l; _s_right = spr_idle_r;
    }
    
    // Seleciona baseado no ângulo (Setores de 90 graus)
    // Direita: 315° a 45°
    if (_angle >= 315 || _angle < 45) {
        sprite_index = _s_right;
        facing_direction = 0; 
    }
    // Cima: 45° a 135°
    else if (_angle >= 45 && _angle < 135) {
        sprite_index = _s_up;
        facing_direction = 90;
    }
    // Esquerda: 135° a 225°
    else if (_angle >= 135 && _angle < 225) {
        sprite_index = _s_left;
        facing_direction = 180;
    }
    // Baixo: 225° a 315°
    else {
        sprite_index = _s_down;
        facing_direction = 270;
    }
});