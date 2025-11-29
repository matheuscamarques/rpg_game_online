// --- LÓGICA VISUAL (Cor) ---
// Se quiser reativar efeitos visuais de estado no futuro, coloque aqui.
// Por enquanto, deixamos o sprite normal pois o obj_Hitbox fará o visual do ataque.
if (remote_state == 1) {
    // image_blend = c_red; 
} else {
    // image_blend = c_white;
}

draw_self(); // Desenha o boneco
draw_equipment();
// --- Configuração do Texto ---
draw_set_color(c_white);    
draw_set_halign(fa_center); 
draw_set_valign(fa_bottom); 

// --- CORREÇÃO CRÍTICA PARA HTML5 ---
// 1. Verifica se é uma struct válida antes de tentar ler
if (is_struct(char_info)) {
    
    // 2. Só então verifica a variável dentro
    if (variable_struct_exists(char_info, "name")) {
        draw_text_transformed(x, y - 10, char_info.name, 0.3, 0.3, 0);
    }
}

// --- Reset das configurações ---
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// --- Debug Box ---
draw_set_color(c_red);
draw_rectangle(bbox_left, bbox_top, bbox_right, bbox_bottom, true);