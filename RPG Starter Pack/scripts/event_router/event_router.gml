/// @function event_router(event_type)
/// @description Retorna a função correspondente ao evento ou undefined
/// @param {string} _event_type O nome do evento (ex: "player_moved")
function event_router(_event_type) {
    
    // STATIC: Essa struct é criada apenas 1 vez na vida do jogo.
    // Super rápido e sem custo de memória repetitivo.
    static _event_map = {
        "welcome":         on_welcome,
        "current_players": on_current_players,
        "player_moved":    on_player_moved,
        "player_left":     on_player_left,
        "phx_reply":       on_phx_reply,
		"new_msg":		   on_chat_message,
		"damage_applied":  on_damage_applied,
		"enemy_update":    on_enemy_update,
		"enemy_died": on_enemy_died,
		"xp_gain": on_xp_gain,
		"world_update" : on_world_update
    };
	
	if (instance_exists(obj_Chat))
		obj_Chat.add_message("Receive this event type from server: " + _event_type, c_yellow, CHAT_CHANNEL.SERVER);
    // Retorna a função associada OU undefined se não existir
    return _event_map[$ _event_type];
}