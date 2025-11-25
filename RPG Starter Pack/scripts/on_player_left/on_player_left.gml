/// @function on_player_left(payload)
function on_player_left(_payload) {
    var _id_sair = string(_payload.id);
    var _map = obj_Network.remote_players_map;
    
    if (ds_map_exists(_map, _id_sair)) {
        var _inst = _map[? _id_sair];
        if (instance_exists(_inst)) {
            instance_destroy(_inst); // Destroi o boneco da tela
        }
        ds_map_delete(_map, _id_sair); // Remove da memória
        show_debug_message(">>> [SAIU] Jogador removido: " + _id_sair);
    }
}