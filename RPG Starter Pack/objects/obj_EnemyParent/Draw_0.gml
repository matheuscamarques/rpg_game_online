event_inherited();
draw_self();

// Debug: Mostrar ID acima da cabeça



draw_set_color(c_red);    // Define a cor branca
draw_set_halign(fa_center); // (Opcional) Centraliza o texto horizontalmente em relação ao X
draw_set_valign(fa_bottom); // (Opcional) Faz o texto crescer para cima a partir do ponto Y

// Desenha o nome
// Nota: Se usar fa_bottom, o y-20 fará o texto ficar 20px acima do ponto de origem
draw_text_transformed(x, y - 10, network_id, 0.3, 0.3, 0);

// --- Reset das configurações (Boa Prática) ---
// É importante resetar o alinhamento para não quebrar outros desenhos no jogo
draw_set_halign(fa_left);
draw_set_valign(fa_top);

