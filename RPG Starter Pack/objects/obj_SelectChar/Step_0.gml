/// EVENTO STEP: obj_selecao_char

var mouse_click = mouse_check_button_pressed(mb_left);

// ==========================================================
// MODO 0: MODAL DE CONFIRMAÇÃO (Bloqueia tudo o resto)
// ==========================================================
if (slot_deletando != -1) {
    var mx = room_width / 2;
    var my = room_height / 2;
    
    // Botão SIM (Deletar)
    if (point_in_rectangle(mouse_x, mouse_y, mx - 110, my + 20, mx - 10, my + 60) && mouse_click) {
        // Apaga da lista e salva a alteração (se tiver save system)
        array_delete(global.personagens, slot_deletando, 1);
        
        slot_deletando = -1; // Fecha modal
        
        // Ajuste de segurança do scroll (para não ficar vendo o vazio)
        var nova_altura = (array_length(global.personagens) + 1) * (slot_altura + 10);
        if (view_altura - nova_altura > scroll_y) scroll_y = max(view_altura - nova_altura, 0);
    }
    
    // Botão NÃO (Cancelar)
    if (point_in_rectangle(mouse_x, mouse_y, mx + 10, my + 20, mx + 110, my + 60) && mouse_click) {
        slot_deletando = -1; 
    }
    
    exit; // PARE O CÓDIGO AQUI. Não deixa fazer mais nada.
}

// ==========================================================
// MODO 1: LISTA (Navegação)
// ==========================================================
if (estado == "LISTA") {
    
    // --- LÓGICA DE SCROLL ---
    var qtd_itens = array_length(global.personagens) + 1; // +1 botão Novo
    altura_total_lista = qtd_itens * (slot_altura + 10);
    
    if (mouse_wheel_up()) scroll_y += scroll_velocidade;
    if (mouse_wheel_down()) scroll_y -= scroll_velocidade;
    
    // Trava o scroll nos limites
    var min_y = view_altura - altura_total_lista;
    if (min_y > 0) min_y = 0; 
    scroll_y = clamp(scroll_y, min_y, 0);

    // --- LOOP DOS SLOTS ---
    for (var i = 0; i < qtd_itens; i++) {
        var _y_real = lista_y_inicial + (i * (slot_altura + 10)) + scroll_y;
        
        // Só processa se estiver visível na tela
        if (_y_real > 0 && _y_real < room_height) {
            
            // Mouse sobre o Slot?
            if (point_in_rectangle(mouse_x, mouse_y, lista_x, _y_real, room_width, _y_real + slot_altura)) {
                
                var clicou_delete = false;
                
                // [A] BOTÃO DELETAR "X" (Apenas chars existentes)
                if (i < array_length(global.personagens)) {
                    var del_x = room_width - 30; 
                    var del_y = _y_real + 15;
                    
                    if (point_in_circle(mouse_x, mouse_y, del_x, del_y, 12)) {
                        if (mouse_click) {
                            slot_deletando = i; // Abre modal
                            clicou_delete = true;
                        }
                    }
                }
                
                // [B] CLIQUE NO SLOT (JOGAR ou CRIAR)
                if (mouse_click && !clicou_delete) {
                    if (i < array_length(global.personagens)) {
                        // JOGAR
                        global.char_ativo = global.personagens[i];
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
    
    // Input Nome (Max 12 chars)
    if (string_length(keyboard_string) <= 12) input_nome = keyboard_string; 
    else keyboard_string = input_nome;
    
    // Troca de Classe
    if (keyboard_check_pressed(vk_right)) { 
        classe_idx++; 
        if (classe_idx >= array_length(classes_nomes)) classe_idx = 0; 
    }
    if (keyboard_check_pressed(vk_left)) { 
        classe_idx--; 
        if (classe_idx < 0) classe_idx = array_length(classes_nomes) - 1; 
    }
    
    // Botão Confirmar
    var btn_w = 200; var btn_h = 40;
    var btn_x = (room_width - lista_largura) / 2 - (btn_w / 2);
    var btn_y = room_height - 100;
    
    if (point_in_rectangle(mouse_x, mouse_y, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h) && mouse_click) {
        if (input_nome != "") {
            var novo_char = { 
                nome: input_nome, 
                classe: classes_nomes[classe_idx], 
                sprite: classes_sprites[classe_idx], 
                nivel: 1 
            };
            array_push(global.personagens, novo_char);
            
            estado = "LISTA"; 
            scroll_y = 0; // Volta ao topo
        }
    }
    
    // Cancelar (ESC)
    if (keyboard_check_pressed(vk_escape)) estado = "LISTA";
}