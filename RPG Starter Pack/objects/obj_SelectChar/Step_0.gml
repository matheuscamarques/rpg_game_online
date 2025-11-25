/// EVENTO STEP: obj_selecao_char

var mouse_click = mouse_check_button_pressed(mb_left);

// ==========================================================
// MODO 0: MODAL DE CONFIRMAÇÃO (Bloqueia tudo)
// ==========================================================
if (slot_deletando != -1) {
    var mx = room_width / 2;
    var my = room_height / 2;
    
    // Botão SIM (Deletar)
    if (point_in_rectangle(mouse_x, mouse_y, mx - 110, my + 20, mx - 10, my + 60) && mouse_click) {
        
        // Pega o ID do banco de dados
        var _char_to_delete = global.personagens[slot_deletando];
        var _id_banco = _char_to_delete.id; 

        // API DELETE
        var _url = global.api_url + "/characters/" + string(_id_banco);
        var _header = ds_map_create();
        ds_map_add(_header, "Authorization", "Bearer " + global.api_token);

        request_delete = http_request(_url, "DELETE", _header, "");
        ds_map_destroy(_header);

        slot_deletando = -1; // Fecha modal
        
        // Ajuste visual do scroll
        var nova_altura = (array_length(global.personagens) + 1) * (slot_altura + 10);
        if (view_altura - nova_altura > scroll_y) scroll_y = max(view_altura - nova_altura, 0);
    }
    
    // Botão NÃO (Cancelar)
    if (point_in_rectangle(mouse_x, mouse_y, mx + 10, my + 20, mx + 110, my + 60) && mouse_click) {
        slot_deletando = -1; 
    }
    
    exit; // PARE O CÓDIGO AQUI
}

// ==========================================================
// MODO 1: LISTA (Navegação)
// ==========================================================
if (estado == "LISTA") {
    
    var qtd_itens = array_length(global.personagens) + 1; // +1 botão Novo
    altura_total_lista = qtd_itens * (slot_altura + 10);
    
    if (mouse_wheel_up()) scroll_y += scroll_velocidade;
    if (mouse_wheel_down()) scroll_y -= scroll_velocidade;
    
    var min_y = view_altura - altura_total_lista;
    if (min_y > 0) min_y = 0; 
    scroll_y = clamp(scroll_y, min_y, 0);

    for (var i = 0; i < qtd_itens; i++) {
        var _y_real = lista_y_inicial + (i * (slot_altura + 10)) + scroll_y;
        
        if (_y_real > 0 && _y_real < room_height) {
            
            if (point_in_rectangle(mouse_x, mouse_y, lista_x, _y_real, room_width, _y_real + slot_altura)) {
                
                var clicou_delete = false;
                
                // [A] BOTÃO DELETAR "X"
                if (i < array_length(global.personagens)) {
                    var del_x = room_width - 30; 
                    var del_y = _y_real + 15;
                    
                    if (point_in_circle(mouse_x, mouse_y, del_x, del_y, 12)) {
                        if (mouse_click) {
                            slot_deletando = i; 
                            clicou_delete = true;
                        }
                    }
                }
                
                // [B] CLIQUE NO SLOT
                if (mouse_click && !clicou_delete) {
                    if (i < array_length(global.personagens)) {
                        // JOGAR
                        global.char_ativo = global.personagens[i];
                        // Certifique-se que Room1 existe
                        room_goto(Room1); 
                    } else {
                        // CRIAR NOVO
                        estado = "CRIANDO";
                        input_nome = "";
                        keyboard_string = "";
                        classe_idx = 0;
                    }
                }
            }
        }
    }
}

// ==========================================================
// MODO 2: CRIANDO (Formulário)
// ==========================================================
else if (estado == "CRIANDO") {
    
    if (string_length(keyboard_string) <= 12) input_nome = keyboard_string; 
    else keyboard_string = input_nome;
    
    if (keyboard_check_pressed(vk_right)) { 
        classe_idx++; 
        if (classe_idx >= array_length(classes_nomes)) classe_idx = 0; 
    }
    if (keyboard_check_pressed(vk_left)) { 
        classe_idx--; 
        if (classe_idx < 0) classe_idx = array_length(classes_nomes) - 1; 
    }
    
    // Botão Confirmar Criação
    var btn_w = 200; var btn_h = 40;
    var btn_x = (room_width - lista_largura) / 2 - (btn_w / 2);
    var btn_y = room_height - 100;
    
    if (point_in_rectangle(mouse_x, mouse_y, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h) && mouse_click) {
        if (input_nome != "") {
            
            // API POST
            var _body_struct = {
                name: input_nome,
                class: classes_nomes[classe_idx],
                level: 1,
                sprite_idx: classe_idx // Envia o número (0, 1...) para o banco
            };
            var _json_str = json_stringify(_body_struct);
    
            var _header = ds_map_create();
            ds_map_add(_header, "Content-Type", "application/json");
            ds_map_add(_header, "Authorization", "Bearer " + global.api_token);
    
            request_create = http_request(global.api_url + "/characters", "POST", _header, _json_str);
            ds_map_destroy(_header);
        }
    }
    
    if (keyboard_check_pressed(vk_escape)) estado = "LISTA";
}