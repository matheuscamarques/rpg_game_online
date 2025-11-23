/// @function net_on_current_players(payload)
function on_current_players(_payload) {
    var _lista = _payload.players;
    var _qtd = array_length(_lista);
    show_debug_message(">>> [SYNC] Processando " + string(_qtd) + " jogadores...");
    
    for (var i = 0; i < _qtd; i++) {
        var _p = _lista[i];
        var _spr = variable_struct_exists(_p, "spr") ? _p.spr : undefined;
        
        // Chama a função utilitária (que também deve virar script)
        sync_remote_player(_p.id, real(_p.x), real(_p.y), _spr);
    }
}