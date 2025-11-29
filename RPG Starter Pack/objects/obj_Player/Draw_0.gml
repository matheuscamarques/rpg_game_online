// 1. Desenha o Player Base
draw_self(); 
draw_equipment()

// --- Resto da UI (Nome e Debug) ---
draw_set_color(c_white);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);

draw_text_transformed(x, y - 10, global.char_ativo.name, 0.3, 0.3, 0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);

draw_set_color(c_red);
draw_rectangle(bbox_left, bbox_top, bbox_right, bbox_bottom, true);