/// EVENTO DRAW: obj_InputRegister

draw_set_halign(fa_left);
draw_set_valign(fa_middle);

// Função auxiliar simples para não repetir código de desenho 4 vezes
// (Dica: Se ficar confuso, me avise que faço do jeito "extenso")

var labels = ["Email:", "Usuario:", "Password:", "Re-password:"];
var textos = [email_texto, user_texto, senha_texto, check_texto];

for (var i = 0; i < 4; i++) {
    var _yy = y + (i * 70); // Desce 70 pixels para cada campo
    
    // Desenha caixa
    if (campo_ativo == i) draw_set_color(c_lime); else draw_set_color(c_white);
    draw_rectangle(x, _yy, x + 200, _yy + 30, true);
    
    // Desenha Label e Texto
    draw_set_color(c_white);
    draw_text(x, _yy - 15, labels[i]);
    
    // Se for senha (índice 2 ou 3), usa asterisco
    var _txt_visual = textos[i];
    if (i >= 2) _txt_visual = string_repeat("*", string_length(_txt_visual));
    
    draw_text(x + 5, _yy + 15, _txt_visual);
}

// --- MENSAGEM DE ERRO (Topo) ---
if (msg_erro != "") {
    draw_set_color(c_red);
    draw_set_halign(fa_center);
    draw_text(x + 100, y - 45, msg_erro);
}

// --- BOTÕES ---
var x1_voltar = x; 
var x1_reg = x + btn_w + espaco;

// Botão Voltar
if (point_in_rectangle(mouse_x, mouse_y, x1_voltar, btn_y, x1_voltar + btn_w, btn_y + btn_h)) 
    draw_set_color(cor_bordo_hover); else draw_set_color(cor_bordo);
draw_rectangle(x1_voltar, btn_y, x1_voltar + btn_w, btn_y + btn_h, false);
draw_set_color(c_white); draw_set_halign(fa_center);
draw_text(x1_voltar + btn_w/2, btn_y + btn_h/2, "Voltar");

// Botão Registrar
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, btn_y, x1_reg + btn_w, btn_y + btn_h)) 
    draw_set_color(cor_bordo_hover); else draw_set_color(cor_bordo);
draw_rectangle(x1_reg, btn_y, x1_reg + btn_w, btn_y + btn_h, false);
draw_set_color(c_white);
draw_text(x1_reg + btn_w/2, btn_y + btn_h/2, "Registrar");