draw_self(); // Desenha o boneco

// Desenha a caixa de colisão real em vermelho (sem preenchimento)
draw_set_color(c_red);
draw_rectangle(bbox_left, bbox_top, bbox_right, bbox_bottom, true);