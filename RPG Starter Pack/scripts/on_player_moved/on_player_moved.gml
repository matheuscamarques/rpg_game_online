/// @function net_on_player_moved(payload)
function on_player_moved(_payload) {
    var _spr = variable_struct_exists(_payload, "spr") ? _payload.spr : undefined;
    sync_remote_player(_payload.id, real(_payload.x), real(_payload.y), _spr);
}