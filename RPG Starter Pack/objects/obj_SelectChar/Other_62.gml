/// EVENTO ASYNC - HTTP: obj_selecao_char

var _id = ds_map_find_value(async_load, "id");
var _status = ds_map_find_value(async_load, "status");

if (_status < 0) exit; // Erro de conexão, sai.

// --- 1. RESPOSTA DO LOAD (GET) ---
if (_id == request_load) {
    var _http_status = ds_map_find_value(async_load, "http_status");
    var _result = ds_map_find_value(async_load, "result");
    
    if (_http_status == 200) {
        try {
            var _dados = json_parse(_result);
            
            if (_dados.status == "success") {
                var _lista_recebida = _dados.personagens;
                
                // FIX CRÍTICO: Converter número do banco em Sprite do GM
                for (var i = 0; i < array_length(_lista_recebida); i++) {
                    var _char = _lista_recebida[i];
                    var _idx = _char.sprite; // Vem 0, 1, 2...
                    
                    // Valida índice e atribui o Asset
                    if (_idx >= 0 && _idx < array_length(classes_sprites)) {
                        _char.sprite = classes_sprites[_idx]; 
                    } else {
                        _char.sprite = classes_sprites[0]; // Fallback
                    }
                }
                
                global.personagens = _lista_recebida;
                show_debug_message("Lista carregada com sucesso!");
            }
        } catch(_e) {
            show_debug_message("Erro JSON Load: " + _e.message);
        }
    }
}

// --- 2. RESPOSTA DO CREATE (POST) ---
if (_id == request_create) {
    var _http_status = ds_map_find_value(async_load, "http_status");
    
    if (_http_status == 200) {
        var _res = json_parse(ds_map_find_value(async_load, "result"));
        
        if (_res.status == "success") {
            // Recarrega a lista para mostrar o novo
            var _header = ds_map_create();
            ds_map_add(_header, "Authorization", "Bearer " + global.api_token);
            request_load = http_request(global.api_url + "/characters", "GET", _header, "");
            ds_map_destroy(_header);
            
            estado = "LISTA"; 
        }
    } else {
        show_debug_message("Erro Create: " + string(_http_status));
    }
}

// --- 3. RESPOSTA DO DELETE (DELETE) ---
if (_id == request_delete) {
    var _http_status = ds_map_find_value(async_load, "http_status");
    
    if (_http_status == 200) {
        // Recarrega a lista
        var _header = ds_map_create();
        ds_map_add(_header, "Authorization", "Bearer " + global.api_token);
        request_load = http_request(global.api_url + "/characters", "GET", _header, "");
        ds_map_destroy(_header);
    }
}