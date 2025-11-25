/// EVENTO ASYNC - HTTP: obj_input_login

var _id = ds_map_find_value(async_load, "id");

// Verifica se a resposta que chegou é a do nosso pedido de login
if (_id == request_login) {
    var _status_http = ds_map_find_value(async_load, "http_status");
    var _result = ds_map_find_value(async_load, "result");
    
    // Status 200 significa que o Phoenix aceitou (retornou {:ok, token})
    if (_status_http == 200) {
        var _dados = json_parse(_result);
        
        if (_dados.status == "success") {
            // SUCESSO!
            // 1. Salva o Token Globalmente (ESSENCIAL PARA O RESTO DO JOGO)
            global.api_token = _dados.token; 
            
            // 2. Salva o nome apenas para exibição
            global.nome_jogador = login_texto; 
            
            // 3. Vai para a seleção de personagens
            room_goto(rm_select); 
        }
    } 
    else {
        // ERRO (Senha errada, usuário não existe, etc)
        // O Phoenix retorna 401 Unauthorized com a mensagem
        shake_timer = 10;
        senha_texto = ""; // Limpa a senha por segurança
        
        try {
            var _dados = json_parse(_result);
            if (variable_struct_exists(_dados, "message")) {
                msg_erro = _dados.message; // "Credenciais inválidas"
            } else {
                msg_erro = "Erro no Login";
            }
        } catch(_e) {
            msg_erro = "Erro de Conexão (" + string(_status_http) + ")";
        }
    }
}