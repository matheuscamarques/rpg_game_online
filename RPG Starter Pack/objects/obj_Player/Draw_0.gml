draw_self(); // Desenha o boneco

// --- Configuração do Texto ---
draw_set_color(c_white);    // Define a cor branca
draw_set_halign(fa_center); // (Opcional) Centraliza o texto horizontalmente em relação ao X
draw_set_valign(fa_bottom); // (Opcional) Faz o texto crescer para cima a partir do ponto Y

// Desenha o nome
// Nota: Se usar fa_bottom, o y-20 fará o texto ficar 20px acima do ponto de origem
draw_text_transformed(x, y - 10, global.char_ativo.name, 0.3, 0.3, 0);

// --- Reset das configurações (Boa Prática) ---
// É importante resetar o alinhamento para não quebrar outros desenhos no jogo
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// --- Debug Box ---
draw_set_color(c_red);
draw_rectangle(bbox_left, bbox_top, bbox_right, bbox_bottom, true);