function on_current_players(_payload) {
    var _lista = _payload.players;
    
    for (var i = 0; i < array_length(_lista); i++) {
        var _p = _lista[i];
        
        // --- EXTRAÇÃO SEGURA DOS DADOS NOVOS ---
        // O servidor manda: x, y, spr, char, state, face
        
        var _state = 0;
        if (variable_struct_exists(_p, "state")) _state = _p.state;
        
        var _face = 270;
        if (variable_struct_exists(_p, "face")) _face = _p.face;
        
        // Agora passamos TUDO para a função de sync
        sync_remote_player(_p.id, _p.x, _p.y, _p.spr, _p.char, _state, _face); 
    }
}