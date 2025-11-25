function on_player_moved(_payload) {
    // Note que se for só movimento, as vezes o 'char' pode vir undefined se o backend não mandar
    // Mas no seu 'join' e 'presence' atual, ele sempre manda tudo.
    
    var _char_data = undefined;
    if (variable_struct_exists(_payload, "char")) _char_data = _payload.char;
    
    sync_remote_player(_payload.id, _payload.x, _payload.y, _payload.spr, _char_data);
}