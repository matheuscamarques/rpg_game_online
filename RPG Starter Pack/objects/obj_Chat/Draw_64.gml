draw_set_font(font_pt);
var _gui_w = display_get_gui_width();
var _gui_h = display_get_gui_height();

// 3% de margem horizontal e vertical
var _margin_x = floor(_gui_w * 0.03); 
var _margin_y = floor(_gui_h * 0.03); 

gui_x = _margin_x;
gui_y = _gui_h - chat_height - _margin_y;

var _tabs_y = gui_y - tab_height;

for (var i = 0; i < array_length(tabs); i++) {
    var _t = tabs[i];
    var _tx = gui_x + (i * tab_width);
    
    // Define cor da aba: Mais clara se selecionada, escura se inativa
    var _tab_color = (current_tab == _t.type) ? c_dkgray : c_black;
    var _alpha = (current_tab == _t.type) ? 0.8 : 0.4;
    
    // Fundo da aba
    draw_set_color(_tab_color);
    draw_set_alpha(_alpha);
    draw_rectangle(_tx, _tabs_y, _tx + tab_width - 2, gui_y, false);
    
    // Texto da aba
    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_tx + (tab_width / 2), _tabs_y + (tab_height / 2), _t.name);
}

// Reseta alinhamento
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// ---------------- DESENHAR FUNDO DO CHAT ----------------
draw_set_color(c_black);
draw_set_alpha(0.4);
draw_rectangle(gui_x, gui_y, gui_x + chat_width, gui_y + chat_height, false);
draw_set_alpha(1);

// ---------------- DESENHAR MENSAGENS (COM FILTRO) ----------------
var _size = ds_list_size(chat_log);
var _draw_y = gui_y + chat_height - line_height; 
if (is_typing) _draw_y -= line_height; // Sobe se estiver digitando

// Loop reverso (do mais novo para o mais antigo)
for (var i = _size - 1; i >= 0; i--) {
    // Pega a struct da mensagem
    var _msg = chat_log[| i];
    
    // --- O FILTRO ACONTECE AQUI ---
    // Se o canal da mensagem não for igual à aba atual, pule para o próximo loop
    // (A menos que você queira que a aba GERAL mostre tudo, aí use um "||")
    if (_msg.channel != current_tab) continue;
    
    // Se passou do topo da janela, para de desenhar (otimização)
    if (_draw_y < gui_y) break;
    
    // Desenha
    draw_set_color(_msg.color);
    draw_text(gui_x + 5, _draw_y, _msg.text); // +5 para padding lateral
    
    // Só decrementa o Y se a mensagem foi realmente desenhada
    _draw_y -= line_height;
}

// ---------------- CAIXA DE INPUT ----------------
if (is_typing) {
    var _input_y = gui_y + chat_height - line_height;
    draw_set_color(c_black);
    draw_set_alpha(0.7);
    draw_rectangle(gui_x, _input_y, gui_x + chat_width, _input_y + line_height, false);
    
    draw_set_alpha(1);
    draw_set_color(c_white);
    blink_timer++;
    var _cursor = (blink_timer % 60 < 30) ? "|" : "";
    draw_text(gui_x + 5, _input_y, "[Dizer]: " + input_text + _cursor);
}