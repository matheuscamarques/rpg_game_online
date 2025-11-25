/// EVENTO ASYNC HTTP: obj_InputRegister

var _id = ds_map_find_value(async_load, "id");

if (_id == request_register) {
    var _http_status = ds_map_find_value(async_load, "http_status");
    var _result = ds_map_find_value(async_load, "result");
    
    // O Phoenix retorna 201 Created para sucesso
    if (_http_status == 201) {
        var _dados = json_parse(_result);
        
        if (_dados.status == "success") {
            // SUCESSO!
            msg_erro = "Conta Criada! Faça Login.";
            
            // Opcional: Limpar os campos
            user_texto = ""; email_texto = ""; senha_texto = ""; check_texto = "";
            
            // Força a cor verde no próximo Draw (já fizemos essa lógica no Draw anterior)
            // Aguarda 1 segundo e manda pro login automaticamente?
            // Ou deixa o usuário clicar em "Voltar". 
            // Vamos deixar a mensagem lá. Se ele clicar em Voltar, vai pro login.
        }
    }
    else {
        // --- ERRO (HTTP 400 ou 500) ---
        shake_timer = 10;
        
        try {
            var _dados = json_parse(_result);
            
            // Tenta pegar a mensagem geral
            if (variable_struct_exists(_dados, "message")) {
                msg_erro = _dados.message; 
            }
            
            // Tenta pegar erros específicos do Ecto (errors: { email: [...], username: [...] })
            if (variable_struct_exists(_dados, "errors")) {
                var _errors = _dados.errors;
                
                // Prioridade de exibição de erro: Email > Username > Password
                if (variable_struct_exists(_errors, "email")) {
                    msg_erro = "Email: " + _errors.email[0]; // Pega o primeiro erro do array
                }
                else if (variable_struct_exists(_errors, "username")) {
                    msg_erro = "User: " + _errors.username[0];
                }
                else if (variable_struct_exists(_errors, "password")) {
                    msg_erro = "Senha: " + _errors.password[0];
                }
            }
        } catch(_e) {
            msg_erro = "Erro no servidor (" + string(_http_status) + ")";
        }
    }
}