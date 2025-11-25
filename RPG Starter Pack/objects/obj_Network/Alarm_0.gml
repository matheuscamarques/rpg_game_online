show_debug_message(">>> [PHOENIX] Enviando Join com Personagem...");

// Dados iniciais do jogador Local
// Se você já spawnou o obj_Player na Room1, pegue o X/Y dele
var _x = 200; 
var _y = 200;
if (instance_exists(obj_Player)) {
    _x = obj_Player.x;
    _y = obj_Player.y;
}

// Pega o Sprite do personagem selecionado anteriormente
var _spr_asset = global.char_ativo.sprite; // Asset do GM (ex: spr_mago)
var _spr_index = sprite_get_name(_spr_asset); // Opcional: Mandar nome ou ID. 
// Vamos mandar o ID do sprite (índice numérico) para facilitar sync remoto
var _spr_id = _spr_asset; 

var _payload = {
    x: _x,
    y: _y,
    spr: _spr_id,
	char: global.char_ativo
};

phoenix_send(socket, my_topic, "phx_join", _payload);