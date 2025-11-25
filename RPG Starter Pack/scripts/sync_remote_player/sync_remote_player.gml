/// @function sync_remote_player(id, x, y, spr, char_data)
function sync_remote_player(_p_id, _p_x, _p_y, _p_spr, _char_data) { // <--- Novo argumento
    
    var _str_id = string(_p_id);
    if (!instance_exists(obj_Network)) return;
    var _my_id = obj_Network.my_id;
    if (_str_id == string(_my_id)) return; 
    var _map = obj_Network.remote_players_map;

    var _inst = undefined;

    // --- CENÁRIO A: JÁ EXISTE ---
    if (ds_map_exists(_map, _str_id)) {
        _inst = _map[? _str_id];
        if (instance_exists(_inst)) {
            _inst.target_x = _p_x;
            _inst.target_y = _p_y;
            if (!is_undefined(_p_spr)) _inst.sprite_index = real(_p_spr);
        }
    } 
    // --- CENÁRIO B: NOVO ---
    else {
        _inst = instance_create_layer(_p_x, _p_y, "Instances", obj_RemotePlayer);
        _inst.network_id = _str_id;
        _inst.target_x = _p_x;
        _inst.target_y = _p_y;
        if (!is_undefined(_p_spr)) _inst.sprite_index = real(_p_spr);
        ds_map_add(_map, _str_id, _inst);
    }

    // --- ATUALIZA DADOS DO PERSONAGEM (Nome, Classe, etc) ---
    // Verifica se _char_data não é undefined e se a instância existe
    if (!is_undefined(_char_data) && instance_exists(_inst)) {
        // Salva os dados dentro do boneco remoto para desenhar depois
        // Ex: No Draw do obj_RemotePlayer você usa: draw_text(x, y-20, char_data.name)
        _inst.char_info = _char_data; 
    }
}