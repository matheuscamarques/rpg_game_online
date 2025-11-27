function on_player_moved(_payload) {
    var _char_data = undefined;
    if (variable_struct_exists(_payload, "char")) _char_data = _payload.char;
    
    // --- NOVO: Extração do Estado ---
    var _state = 0; // Default: FREE
    if (variable_struct_exists(_payload, "state")) {
        _state = _payload.state;
    }
	
	var _face = 270;
    if (variable_struct_exists(_payload, "face")) _face = _payload.face;
    

    sync_remote_player(_payload.id, _payload.x, _payload.y, _payload.spr, _char_data, _state, _face);
}