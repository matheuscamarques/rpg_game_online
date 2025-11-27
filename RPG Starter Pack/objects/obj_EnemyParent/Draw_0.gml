draw_self();

// Debug: Mostrar ID acima da cabeça
draw_set_halign(fa_center);
draw_text_transformed(x, y - 25, network_id, 0.5, 0.5, 0);
draw_set_halign(fa_left);