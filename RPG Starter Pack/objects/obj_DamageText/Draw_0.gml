draw_set_font(font_pt);

// Centraliza o texto para ele nascer exatamente no meio do personagem
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_alpha(clamp(alpha, 0, 1)); // Garante que alpha não bugue o desenho

var _x = x;
var _y = y;
var _s = scale;

// --- DESENHAR CONTORNO (Sombra/Outline) ---
draw_set_color(c_black);
// Desenha 1 pixel para cada lado para criar a borda
draw_text_transformed(_x+1, _y, text, _s, _s, 0);
draw_text_transformed(_x-1, _y, text, _s, _s, 0);
draw_text_transformed(_x, _y+1, text, _s, _s, 0);
draw_text_transformed(_x, _y-1, text, _s, _s, 0);

// --- DESENHAR TEXTO PRINCIPAL ---
draw_set_color(color);
draw_text_transformed(_x, _y, text, _s, _s, 0);

// --- RESET (Boa prática) ---
draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);