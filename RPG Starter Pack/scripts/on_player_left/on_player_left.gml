/// @function net_on_player_left(payload)
function on_player_left(_payload) {
    var _p_id = string(_payload.id);
    
    // Acessa o mapa dentro do obj_Network
    if (ds_map_exists(obj_Network.remote_players_map, _p_id)) {
        var _inst = obj_Network.remote_players_map[? _p_id];
        if (instance_exists(_inst)) instance_destroy(_inst);
        ds_map_delete(obj_Network.remote_players_map, _p_id);
        show_debug_message(">>> [SAIU] ID: " + _p_id);
    }
}