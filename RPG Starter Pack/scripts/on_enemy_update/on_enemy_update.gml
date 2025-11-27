function on_enemy_update(_payload) {
    var _id   = _payload.id;
    var _type = _payload.type;
    var _x    = _payload.x;
    var _y    = _payload.y;
    
    // --- 1. NOVO: EXTRAÇÃO DE ESTADO E DIREÇÃO ---
    // Usamos verificação ternária para segurança (caso o Elixir não mande em algum momento)
    var _state = variable_struct_exists(_payload, "state") ? _payload.state : 0;
    var _face  = variable_struct_exists(_payload, "face")  ? _payload.face  : 270;

    var _inst = undefined;
    var _map = obj_Network.enemies_map;

    if (ds_map_exists(_map, _id)) {
        // --- ATUALIZAÇÃO ---
        _inst = _map[? _id];
        
        if (instance_exists(_inst)) {
            _inst.target_x = _x;
            _inst.target_y = _y;
            
            // --- 2. NOVO: ATUALIZA A LÓGICA DO INIMIGO ---
            // Verifica se a instância tem suporte a combate (remote_state)
            if (variable_instance_exists(_inst, "remote_state")) {
                _inst.remote_state = _state;
            }
            if (variable_instance_exists(_inst, "facing_direction")) {
                _inst.facing_direction = _face;
            }
        } else {
            ds_map_delete(_map, _id);
        }
    } 
    else {
        // --- CRIAÇÃO (SPAWN) ---
        var _asset = get_enemy_asset(_type);
        
        _inst = instance_create_layer(_x, _y, "Instances", _asset);
        
        // Configurações Básicas
        _inst.network_id = _id;
        _inst.target_x = _x;
        _inst.target_y = _y;
        
        // --- 3. NOVO: INICIALIZA ESTADO E DIREÇÃO ---
        // Garante que ele já nasça olhando pro lado certo ou atacando
        if (variable_instance_exists(_inst, "remote_state")) {
            _inst.remote_state = _state;
        }
        if (variable_instance_exists(_inst, "facing_direction")) {
            _inst.facing_direction = _face;
        }
        
        ds_map_add(_map, _id, _inst);
    }
}

// Função Auxiliar (Factory Pattern) - MANTIDA IGUAL
function get_enemy_asset(_type_string) {
    switch (_type_string) {
        case "human": return obj_Human; 
        default:      return obj_EnemyParent; 
    }
}