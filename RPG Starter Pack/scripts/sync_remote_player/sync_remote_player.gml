/// @function sync_remote_player(id, x, y, spr, char_data, state)
// Adicionado _p_state com valor padrão 0 (FREE) para evitar erros se for omitido
function sync_remote_player(_p_id, _p_x, _p_y, _p_spr, _char_data, _p_state = 0, _p_face = 0) { 
    
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
            
            // --- ATUALIZAÇÃO DO ESTADO ---
            // Atualiza o estado visual (0=Normal, 1=Atacando)
            _inst.remote_state = _p_state;
			_inst.facing_direction = _p_face;
        }
    } 
    // --- CENÁRIO B: NOVO ---
    else {
        _inst = instance_create_layer(_p_x, _p_y, "Instances", obj_RemotePlayer);
        _inst.network_id = _str_id;
        _inst.target_x = _p_x;
        _inst.target_y = _p_y;
        if (!is_undefined(_p_spr)) _inst.sprite_index = real(_p_spr);
        
        // --- INICIALIZAÇÃO DO ESTADO ---
        _inst.remote_state = _p_state;
		_inst.facing_direction = _p_face;
        ds_map_add(_map, _str_id, _inst);
    }

    // --- ATUALIZA DADOS DO PERSONAGEM (Nome, Classe, etc) ---
    if (!is_undefined(_char_data) && instance_exists(_inst)) {
        _inst.char_info = _char_data; 
    }
}