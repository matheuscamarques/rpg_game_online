// Input de texto (mantive a lógica anterior, resumida aqui)
if (keyboard_check_pressed(vk_enter)) {
    if (!is_typing) {
        is_typing = true;
        keyboard_string = "";
        input_text = "";
    } else {
        // --- LÓGICA DE ENVIO ---
        if (input_text != "") {
            
            // Verifica se estamos conectados
            if (instance_exists(obj_Network) && obj_Network.connected) {
                
                // Monta o payload para o Elixir
                var _payload = {
                    text: input_text
                    // O Elixir no backend saberá quem enviou pelo Socket ID ou Assigns
                };
                
                // Envia para o servidor (evento "new_msg" ou "shout")
                // Use a variável global ou referencie a instância
                with (obj_Network) {
                    phoenix_send(socket, my_topic, "new_msg", _payload);
                }
                
                // Opcional: Adicionar a mensagem localmente IMEDIATAMENTE (Lag-free feel)
                // OU esperar o servidor devolver a mensagem (mais seguro contra desync)
                // Se for esperar o server, não faça nada aqui.
                // Se quiser mostrar na hora:
                // add_message("Eu: " + input_text, c_ltgray, CHAT_CHANNEL.GENERAL);
            }
        }
        
        is_typing = false;
        input_text = "";
    }
}

if (is_typing) {
    if (string_length(keyboard_string) > 60) keyboard_string = string_copy(keyboard_string, 1, 60);
    input_text = keyboard_string;
}

// --- Lógica de Clique nas Abas ---
if (mouse_check_button_pressed(mb_left)) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    
    // As abas ficam logo acima da janela de chat (gui_y - tab_height)
    var _tabs_y = gui_y - tab_height;
    
    // Checa colisão com cada aba
    for (var i = 0; i < array_length(tabs); i++) {
        var _tab_x1 = gui_x + (i * tab_width);
        var _tab_x2 = _tab_x1 + tab_width;
        
        // Verifica se o mouse está dentro do retângulo da aba
        if (point_in_rectangle(_mx, _my, _tab_x1, _tabs_y, _tab_x2, gui_y)) {
            current_tab = tabs[i].type; // Muda o filtro atual
        }
    }
}