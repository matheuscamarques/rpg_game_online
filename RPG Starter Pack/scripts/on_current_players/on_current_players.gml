function on_current_players(_payload) {
    var _lista = _payload.players;
    for (var i = 0; i < array_length(_lista); i++) {
        var _p = _lista[i];
        // Agora passamos _p.char também
        sync_remote_player(_p.id, _p.x, _p.y, _p.spr, _p.char); 
    }
}