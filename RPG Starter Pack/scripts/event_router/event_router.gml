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
		"new_msg":		   on_chat_message
    };

    // Retorna a função associada OU undefined se não existir
    return _event_map[$ _event_type];
}