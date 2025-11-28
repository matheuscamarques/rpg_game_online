function on_enemy_update(_data) {
    // --- 1. DESCOMPRESSÃO DO PROTOCOLO (ARRAY) ---
    // O backend agora manda: [id, type, x, y, state, face]
    // Acessar array por índice é muito mais rápido que buscar chave de string em struct.
    
    var _id    = string(_data[0]); // Índice 0 = ID
    var _type  = _data[1];         // Índice 1 = Type
    var _x     = _data[2];         // Índice 2 = X
    var _y     = _data[3];         // Índice 3 = Y
    
    // Safety check: Se o array vier curto (versão antiga), usa default
    var _state = (array_length(_data) > 4) ? _data[4] : 0;
    var _face  = (array_length(_data) > 5) ? _data[5] : 270;

    var _map = obj_Network.enemies_map;
    var _inst = undefined;

    if (ds_map_exists(_map, _id)) {
        // --- CENÁRIO: ATUALIZAÇÃO ---
        _inst = _map[? _id];
        
        // TRUQUE HTML5 (Object Pooling): 
        // Se o mob estava longe, seu GC pode tê-lo desativado (instance_deactivate).
        // Precisamos ativá-lo para que ele volte a aparecer e atualizar.
        instance_activate_object(_inst); 
        
        if (instance_exists(_inst)) {
            _inst.target_x = _x;
            _inst.target_y = _y;
            
            // Atualiza Lógica de Combate
            if (variable_instance_exists(_inst, "remote_state")) {
                _inst.remote_state = _state;
            }
            if (variable_instance_exists(_inst, "facing_direction")) {
                _inst.facing_direction = _face;
            }
        } else {
            // Se o ID existe no mapa mas a instância sumiu (bug raro), limpa o mapa
            ds_map_delete(_map, _id);
        }
    } 
    else {
        // --- CENÁRIO: CRIAÇÃO (SPAWN) ---
        var _asset = get_enemy_asset(_type);
        
        _inst = instance_create_layer(_x, _y, "Instances", _asset);
        
        // Configurações Básicas
        _inst.network_id = _id;
        _inst.target_x = _x;
        _inst.target_y = _y;
        
        // Inicializa variáveis de combate
        // Usamos variable_instance_exists para garantir que não crashe se for um mob simples
        if (variable_instance_exists(_inst, "remote_state")) {
            _inst.remote_state = _state;
        }
        if (variable_instance_exists(_inst, "facing_direction")) {
            _inst.facing_direction = _face;
        }
        
        ds_map_add(_map, _id, _inst);
    }
}

// A Factory continua igual
function get_enemy_asset(_type_string) {
    switch (_type_string) {
        case "human": return obj_Human; 
        default:      return obj_EnemyParent; 
    }
}