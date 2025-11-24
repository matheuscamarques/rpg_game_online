/// EVENTO DRAW: obj_input_login

// --- CONFIGURAÇÕES BÁSICAS ---
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
var y_senha = y + 70; // Define a altura da senha para usar nos cálculos

// --- CAMPO 1: LOGIN ---
// Borda: Verde se ativo, Branco se inativo
if (campo_ativo == 0) draw_set_color(c_lime); else draw_set_color(c_white);
draw_rectangle(x, y, x + 200, y + 30, true); 

draw_set_color(c_white);
draw_text(x, y - 15, "Usuario:"); 
draw_text(x + 5, y + 15, login_texto); 


// --- CAMPO 2: SENHA ---
// Borda: Verde se ativo, Branco se inativo
if (campo_ativo == 1) draw_set_color(c_lime); else draw_set_color(c_white);
draw_rectangle(x, y_senha, x + 200, y_senha + 30, true);

draw_set_color(c_white);
draw_text(x, y_senha - 15, "Senha:"); 

// Máscara de senha com asteriscos
var senha_visual = string_repeat("*", string_length(senha_texto));
draw_text(x + 5, y_senha + 15, senha_visual);


// --- MENSAGEM DE ERRO OU SUCESSO (TOPO) ---
if (msg_erro != "") {
    // Se a mensagem for de sucesso, pinta de verde, senão vermelho
    if (msg_erro == "Conta Criada! Faça Login.") draw_set_color(c_lime);
    else draw_set_color(c_red);
    
    draw_set_halign(fa_center);
    draw_text(x + 100, y - 45, msg_erro); 
}


// --- DESENHAR BOTÕES (NOVO) ---

// Definições temporárias para facilitar a leitura (devem bater com o Create)
// btn_y, btn_w, btn_h e espaco vêm do Create
var x1_log = x;
var x2_log = x + btn_w;
var y2_btn = btn_y + btn_h;

var x1_reg = x + btn_w + espaco;
var x2_reg = x + btn_w + espaco + btn_w;

// 1. BOTÃO LOGIN
// Checa se o mouse está em cima para mudar a cor (Hover)
if (point_in_rectangle(mouse_x, mouse_y, x1_log, btn_y, x2_log, y2_btn)) {
    draw_set_color(cor_bordo_hover); 
} else {
    draw_set_color(cor_bordo);
}

draw_rectangle(x1_log, btn_y, x2_log, y2_btn, false); // false = preenchido

draw_set_color(c_white);
draw_set_halign(fa_center);
draw_text(x1_log + (btn_w/2), btn_y + (btn_h/2), "Login");


// 2. BOTÃO REGISTER
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, btn_y, x2_reg, y2_btn)) {
    draw_set_color(cor_bordo_hover); 
} else {
    draw_set_color(cor_bordo);
}

draw_rectangle(x1_reg, btn_y, x2_reg, y2_btn, false);

draw_set_color(c_white);
draw_text(x1_reg + (btn_w/2), btn_y + (btn_h/2), "Register");


// --- INSTRUÇÃO (RODAPÉ) ---
draw_set_halign(fa_left); // Reseta alinhamento
draw_set_color(c_gray);

// Movi para (btn_y + 45) para ficar abaixo dos botões
draw_text(x - 50, btn_y + 45, "TAB: Troca | ENTER: Confirma");