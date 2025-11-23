/// EVENTO: Async - Networking (FINAL - COM ROUTER)

var _type = ds_map_find_value(async_load, "type");

// ---------------------------------------------------------
// TIPO 1: CONEXÃO / DESCONEXÃO
// ---------------------------------------------------------
if (_type == network_type_non_blocking_connect) {
    var _succeeded = ds_map_find_value(async_load, "succeeded");
    
    if (_succeeded) {
        show_debug_message(">>> [CONEXÃO] SUCESSO!");
        connected = true;
        retry_delay = 1;
        alarm[ALARM_JOIN_DELAY] = 10; 
        alarm[ALARM_HEARTBEAT] = game_get_speed(gamespeed_fps) * 30;
        if (layer_exists("Background")) layer_background_blend(layer_background_get_id("Background"), c_green);
    } else {
        show_debug_message(">>> [CONEXÃO] FALHA!");
        connected = false;
        alarm[ALARM_RECONNECT] = game_get_speed(gamespeed_fps) * retry_delay;
        retry_delay = clamp(retry_delay * 2, 1, 32);
        if (layer_exists("Background")) layer_background_blend(layer_background_get_id("Background"), c_red);
    }
}
else if (_type == network_type_disconnect) {
    show_debug_message(">>> [CONEXÃO] CAIU!");
    connected = false;
    socket = -1;
    with (obj_RemotePlayer) instance_destroy();
    ds_map_clear(remote_players_map);
    retry_delay = 1;
    alarm[ALARM_RECONNECT] = 60; 
}

// ---------------------------------------------------------
// TIPO 2: DADOS (ROTEADOR)
// ---------------------------------------------------------
else if (_type == network_type_data) {
    var _buff = ds_map_find_value(async_load, "buffer");
    
    if (_buff != undefined) {
        var _texto = buffer_read(_buff, buffer_text);
        
        try {
            var _json = json_parse(_texto);
            
            if (is_array(_json) && array_length(_json) >= 5) {
                var _evt = _json[3];     // Nome do evento (ex: "player_moved")
                var _payload = _json[4]; // Dados
                
                // --- AQUI ESTÁ A CORREÇÃO ---
                
                // 1. Pergunta ao Script qual função usar
                var _handler_func = event_router(_evt);
                
                // 2. Se existir, executa
                if (!is_undefined(_handler_func)) {
                    _handler_func(_payload);
                } 
                else {
                    // Opcional: Log para debug
                    // show_debug_message(">>> [AVISO] Evento ignorado: " + string(_evt));
                }
            }
        } catch(e) {
            show_debug_message(">>> [ERRO JSON] " + e.message);
        }
    }
}