/// CONFIGURAÇÃO
move_speed = 3.2;       // Velocidade máxima
accel      = 0.2;       // Aceleração (lerp amount 0-1)
friction   = 0.25;      // Fricção (lerp amount 0-1)

hsp = 0;
vsp = 0;

// Pega o ID do Tilemap de colisão
col_obj = layer_tilemap_get_id("Tiles_col");

// REDE
last_sprite = sprite_index;
network_timer = 0;