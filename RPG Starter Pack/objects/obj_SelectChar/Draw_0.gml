/// EVENTO DRAW: obj_selecao_char
draw_set_font(-1); 

// 1. Fundo Lateral
draw_set_color(cor_fundo_lista);
draw_rectangle(lista_x, 0, room_width, room_height, false);

// 2. Loop dos Itens
var qtd_itens = array_length(global.personagens) + 1;

for (var i = 0; i < qtd_itens; i++) {
    var _y = lista_y_inicial + (i * (slot_altura + 10)) + scroll_y;
    
    if (_y < -100 || _y > room_height) continue;
    
    var is_hover = point_in_rectangle(mouse_x, mouse_y, lista_x, _y, room_width, _y + slot_altura);
    
    if (is_hover) draw_set_color(cor_slot_hover); 
    else draw_set_color(cor_slot_normal);
    
    draw_rectangle(lista_x + 10, _y, room_width - 10, _y + slot_altura, false);
    
    draw_set_color(c_white);
    
    if (i < array_length(global.personagens)) {
        // [A] PERSONAGEM
        var _char = global.personagens[i];
        
        draw_set_halign(fa_left); 
        draw_text(lista_x + 20, _y + 10, _char.nome);
        draw_text_transformed(lista_x + 20, _y + 40, _char.classe, 0.8, 0.8, 0);
        
        draw_set_halign(fa_right); 
        draw_text(room_width - 20, _y + 10, "Lv." + string(_char.nivel));
        
        // Desenha o Sprite (Agora é um Asset válido graças ao Async)
        if (sprite_exists(_char.sprite)) {
             draw_sprite_ext(_char.sprite, 0, room_width - 40, _y + 50, 2, 2, 0, c_white, 1);
        }

        // Botão X
        var del_x = room_width - 30; var del_y = _y + 15;
        if (point_in_circle(mouse_x, mouse_y, del_x, del_y, 12)) draw_set_color(c_red); 
        else draw_set_color(make_color_rgb(150, 50, 50));
        draw_circle(del_x, del_y, 10, false);
        draw_set_color(c_white); draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_text_transformed(del_x, del_y, "X", 0.7, 0.7, 0);
        draw_set_valign(fa_top); 
    } else {
        // [B] NOVO
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_text(lista_x + (lista_largura/2), _y + (slot_altura/2), "+ CRIAR NOVO");
        draw_set_valign(fa_top); 
    }
    draw_set_halign(fa_left); 
}

// 3. Cabeçalho (Máscara)
draw_set_color(cor_fundo_lista);
draw_rectangle(lista_x, 0, room_width, 85, false);
draw_set_color(c_white);
draw_text(lista_x + 20, 40, "SEUS HEROIS:");
draw_set_color(c_dkgray);
draw_line(lista_x, 85, room_width, 85);

// 4. Criação
if (estado == "CRIANDO") {
    draw_set_color(c_black); draw_set_alpha(0.7);
    draw_rectangle(0, 0, lista_x, room_height, false);
    draw_set_alpha(1);
    
    var cx = (room_width - lista_largura) / 2;
    var cy = room_height / 2;
    
    draw_set_halign(fa_center);
    draw_set_color(c_yellow);
    draw_text_transformed(cx, cy - 180, "NOVO AVENTUREIRO", 1.5, 1.5, 0);
    
    var spr = classes_sprites[classe_idx];
    draw_sprite_ext(spr, 0, cx, cy - 50, 4, 4, 0, c_white, 1);
    
    draw_set_color(c_white);
    draw_text(cx, cy + 60, "<  " + classes_nomes[classe_idx] + "  >");
    draw_text(cx, cy - 230, "Nome: " + input_nome + (current_time % 1000 < 500 ? "|" : ""));
    
    var btn_w = 200; var btn_h = 40; var btn_x = cx - (btn_w/2); var btn_y = room_height - 100;
    if (point_in_rectangle(mouse_x, mouse_y, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h)) 
        draw_set_color(c_lime); else draw_set_color(cor_slot_hover);
    draw_rectangle(btn_x, btn_y, btn_x + btn_w, btn_y + btn_h, false);
    draw_set_color(c_white); draw_set_valign(fa_middle);
    draw_text(cx, btn_y + (btn_h/2), "CONFIRMAR");
    draw_set_valign(fa_top); draw_set_halign(fa_left);
}

// 5. Modal Deletar
if (slot_deletando != -1) {
    draw_set_color(c_black); draw_set_alpha(0.85);
    draw_rectangle(0, 0, room_width, room_height, false);
    draw_set_alpha(1);
    
    var mx = room_width / 2; var my = room_height / 2;
    draw_set_color(cor_fundo_lista); draw_rectangle(mx - 150, my - 80, mx + 150, my + 80, false);
    draw_set_color(c_white); draw_rectangle(mx - 150, my - 80, mx + 150, my + 80, true);
    
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    var nome_del = global.personagens[slot_deletando].nome;
    draw_text(mx, my - 40, "Deletar " + nome_del + "?");
    
    if (point_in_rectangle(mouse_x, mouse_y, mx - 110, my + 20, mx - 10, my + 60)) 
        draw_set_color(c_red); else draw_set_color(c_maroon);
    draw_rectangle(mx - 110, my + 20, mx - 10, my + 60, false);
    draw_set_color(c_white); draw_text(mx - 60, my + 40, "SIM");
    
    if (point_in_rectangle(mouse_x, mouse_y, mx + 10, my + 20, mx + 110, my + 60)) 
        draw_set_color(c_gray); else draw_set_color(c_dkgray);
    draw_rectangle(mx + 10, my + 20, mx + 110, my + 60, false);
    draw_set_color(c_white); draw_text(mx + 60, my + 40, "NAO");
    draw_set_valign(fa_top); draw_set_halign(fa_left);
}