/// EVENTO DRAW: obj_selecao_char

draw_set_font(-1); // Use sua fonte

// ==========================================================
// 1. DESENHAR BARRA LATERAL (Background)
// ==========================================================
draw_set_color(cor_fundo_lista);
draw_rectangle(lista_x, 0, room_width, room_height, false);

// ==========================================================
// 2. DESENHAR ITENS DA LISTA
// ==========================================================
var qtd_itens = array_length(global.personagens) + 1;

for (var i = 0; i < qtd_itens; i++) {
    var _y = lista_y_inicial + (i * (slot_altura + 10)) + scroll_y;
    
    // Otimização: Não desenha fora da tela
    if (_y < -100 || _y > room_height) continue;
    
    // Hover Effect
    var is_hover = point_in_rectangle(mouse_x, mouse_y, lista_x, _y, room_width, _y + slot_altura);
    
    if (is_hover) draw_set_color(cor_slot_hover); 
    else draw_set_color(cor_slot_normal);
    
    // Desenha o Card
    draw_rectangle(lista_x + 10, _y, room_width - 10, _y + slot_altura, false);
    
    // --- CONTEÚDO ---
    draw_set_color(c_white);
    
    if (i < array_length(global.personagens)) {
        // [A] SLOT DE PERSONAGEM
        var _char = global.personagens[i];
        
        draw_set_halign(fa_left); 
        draw_text(lista_x + 20, _y + 10, _char.nome);
        draw_text_transformed(lista_x + 20, _y + 40, _char.classe, 0.8, 0.8, 0);
        
        draw_set_halign(fa_right); 
        draw_text(room_width - 20, _y + 10, "Lv." + string(_char.nivel));
        
        draw_sprite_ext(_char.sprite, 0, room_width - 40, _y + 50, 0.5, 0.5, 0, c_white, 1);
        
        // --- BOTÃO DELETAR (X) ---
        var del_x = room_width - 30; 
        var del_y = _y + 15;
        
        // Hover no X
        if (point_in_circle(mouse_x, mouse_y, del_x, del_y, 12)) draw_set_color(c_red); 
        else draw_set_color(make_color_rgb(150, 50, 50));
        
        draw_circle(del_x, del_y, 10, false);
        
        draw_set_color(c_white);
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_text_transformed(del_x, del_y, "X", 0.7, 0.7, 0);
        draw_set_valign(fa_top); // Reset
    } 
    else {
        // [B] BOTÃO NOVO PERSONAGEM
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(lista_x + (lista_largura/2), _y + (slot_altura/2), "+ CRIAR NOVO");
        draw_set_valign(fa_top); // Reset
    }
    
    draw_set_halign(fa_left); // Reset Geral
}

// ==========================================================
// 3. CABEÇALHO (MÁSCARA)
// ==========================================================
// Cobre os itens que rolam para cima
draw_set_color(cor_fundo_lista);
draw_rectangle(lista_x, 0, room_width, 85, false);

draw_set_color(c_white);
draw_text(lista_x + 20, 40, "SEUS HEROIS:");
draw_set_color(c_dkgray);
draw_line(lista_x, 85, room_width, 85);

// ==========================================================
// 4. TELA DE CRIAÇÃO (ESQUERDA)
// ==========================================================
if (estado == "CRIANDO") {
    // Escurece o fundo esquerdo
    draw_set_color(c_black);
    draw_set_alpha(0.7);
    draw_rectangle(0, 0, lista_x, room_height, false);
    draw_set_alpha(1);
    
    var cx = (room_width - lista_largura) / 2;
    var cy = room_height / 2;
    
    draw_set_halign(fa_center);
    
    // Título
    draw_set_color(c_yellow);
    draw_text_transformed(cx, cy - 180, "NOVO AVENTUREIRO", 1.5, 1.5, 0);
    
    // Sprite Gigante
    var spr = classes_sprites[classe_idx];
    draw_sprite_ext(spr, 0, cx, cy - 50, 4, 4, 0, c_white, 1);
    
    // Seletor
    draw_set_color(c_white);
    draw_text(cx, cy + 60, "<  " + classes_nomes[classe_idx] + "  >");
    draw_text_transformed(cx, cy + 90, "Setas para trocar", 0.7, 0.7, 0);
    
    // Input Nome
    draw_text(cx, cy - 230, "Nome: " + input_nome + (current_time % 1000 < 500 ? "|" : ""));
    
    // Botão Confirmar
    var btn_w = 200; var btn_h = 40;
    var btn_x = cx - (btn_w/2); var btn_y = room_height - 100;
    
    if (point_in_rectangle(mouse_x, mouse_y, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h)) 
        draw_set_color(c_lime); else draw_set_color(cor_slot_hover);
        
    draw_rectangle(btn_x, btn_y, btn_x + btn_w, btn_y + btn_h, false);
    
    draw_set_color(c_white); draw_set_valign(fa_middle);
    draw_text(cx, btn_y + (btn_h/2), "CONFIRMAR");
    draw_set_valign(fa_top); draw_set_halign(fa_left);
}

// ==========================================================
// 5. MODAL DE DELEÇÃO (POR CIMA DE TUDO)
// ==========================================================
if (slot_deletando != -1) {
    // Fundo Overlay
    draw_set_color(c_black); draw_set_alpha(0.85);
    draw_rectangle(0, 0, room_width, room_height, false);
    draw_set_alpha(1);
    
    var mx = room_width / 2; var my = room_height / 2;
    
    // Janela
    draw_set_color(cor_fundo_lista);
    draw_rectangle(mx - 150, my - 80, mx + 150, my + 80, false);
    draw_set_color(c_white);
    draw_rectangle(mx - 150, my - 80, mx + 150, my + 80, true);
    
    // Texto
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    var nome_del = global.personagens[slot_deletando].nome;
    draw_text(mx, my - 40, "Deletar " + nome_del + "?");
    draw_text_transformed(mx, my - 20, "Isso nao pode ser desfeito.", 0.7, 0.7, 0);
    
    // Botões
    // SIM
    if (point_in_rectangle(mouse_x, mouse_y, mx - 110, my + 20, mx - 10, my + 60)) 
        draw_set_color(c_red); else draw_set_color(c_maroon);
    draw_rectangle(mx - 110, my + 20, mx - 10, my + 60, false);
    draw_set_color(c_white); draw_text(mx - 60, my + 40, "SIM");
    
    // NÃO
    if (point_in_rectangle(mouse_x, mouse_y, mx + 10, my + 20, mx + 110, my + 60)) 
        draw_set_color(c_gray); else draw_set_color(c_dkgray);
    draw_rectangle(mx + 10, my + 20, mx + 110, my + 60, false);
    draw_set_color(c_white); draw_text(mx + 60, my + 40, "NAO");
    
    draw_set_valign(fa_top); draw_set_halign(fa_left);
}