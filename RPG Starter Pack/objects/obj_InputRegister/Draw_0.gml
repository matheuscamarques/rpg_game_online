/// EVENTO DRAW: obj_InputRegister

// --- DEFINIÇÃO DA PALETA (Mesma do Login) ---
var col_elixir_roxo = $7A2C5D;
var col_elixir_escuro = $4F1836; 
var col_texto_claro = $E3DEDE; 
var col_texto_apagado = $A68B9E; 
var col_erro_sombrio = $3333CC;

// --- DESENHAR TÍTULO E CITAÇÃO ---
draw_set_halign(fa_center);
draw_set_valign(fa_top);

draw_set_font(font_pt);
// Título
draw_set_color(col_elixir_roxo);
// Subi um pouco mais (y-220) pois este formulário é mais alto (4 campos)
draw_text_transformed(x + 100, y - 220, "Registro de Alma", 1.5, 1.5, 0); 

// Citação (Epicteto, Enchiridion 51 - Sobre Procrastinação e Melhora)
draw_set_color(col_texto_apagado);
var mensagem_quote = "Até quando, pois, esperarás para exigir o melhor para ti mesmo e em nada transgredir a regra da razão? ... Se fores negligente, e à demora acrescentares demora, sem perceber não farás progresso.";
var altura_linha = 18;
var largura_max = 380; 
// Desenhado acima dos campos
draw_text_ext(x + 100, y - 170, mensagem_quote, altura_linha, largura_max);

// --- CONFIGURAÇÃO DOS CAMPOS ---
draw_set_halign(fa_left);
draw_set_valign(fa_middle);

var labels = ["Email:", "Usuario:", "Password:", "Re-password:"];
var textos = [email_texto, user_texto, senha_texto, check_texto];

// Loop para desenhar os 4 campos
for (var i = 0; i < 4; i++) {
    var _yy = y + (i * 70); // Desce 70 pixels para cada campo
    
    // Borda: Roxo se ativo, Apagado se inativo
    if (campo_ativo == i) draw_set_color(col_elixir_roxo); else draw_set_color(col_texto_apagado);
    draw_rectangle(x, _yy, x + 200, _yy + 30, true);
    
    // Label (Texto fixo acima da caixa)
    draw_set_color(col_texto_claro);
    draw_text(x, _yy - 15, labels[i]);
    
    // Conteúdo digitado
    var _txt_visual = textos[i];
    
    // Se for senha (índice 2) ou confirmação (índice 3), usa asterisco
    if (i >= 2) {
        _txt_visual = string_repeat("*", string_length(_txt_visual));
    }
    
    // Desenha o texto digitado
    draw_set_color(col_texto_claro);
    draw_text(x + 5, _yy + 15, _txt_visual);
}

// --- MENSAGEM DE ERRO (Topo, logo abaixo da citação) ---
if (msg_erro != "") {
    draw_set_color(col_erro_sombrio); // Vermelho escuro
    draw_set_halign(fa_center);
    // Ajustei a posição para não sobrepor o primeiro campo
    draw_text(x + 100, y - 30, msg_erro);
}

// --- BOTÕES ---
// Recalculando posições com base nas variáveis de instância
var x1_voltar = x; 
var x1_reg = x + btn_w + espaco;

// Como são 4 campos, os botões precisam descer mais. 
// O último campo está em: y + (3 * 70) = y + 210. 
// A caixa do último campo tem 30px de altura, terminando em y + 240.
// Vamos posicionar os botões em y + 270.

// Se 'btn_y' estiver fixo no Create, talvez precise sobrescrever aqui ou ajustar no Create.
// Vou usar uma variável local para garantir que fique abaixo dos campos:
var _btn_draw_y = y + 280; 
var _btn_draw_h_end = _btn_draw_y + btn_h;

// 1. Botão Voltar
if (point_in_rectangle(mouse_x, mouse_y, x1_voltar, _btn_draw_y, x1_voltar + btn_w, _btn_draw_h_end)) {
    draw_set_color(cor_bordo_hover); 
} else {
    draw_set_color(cor_bordo);
}
draw_rectangle(x1_voltar, _btn_draw_y, x1_voltar + btn_w, _btn_draw_h_end, false);

draw_set_color(col_texto_claro); 
draw_set_halign(fa_center);
draw_text(x1_voltar + btn_w/2, _btn_draw_y + btn_h/2, "Voltar");


// 2. Botão Registrar
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, _btn_draw_y, x1_reg + btn_w, _btn_draw_h_end)) {
    draw_set_color(cor_bordo_hover); 
} else {
    draw_set_color(cor_bordo);
}
draw_rectangle(x1_reg, _btn_draw_y, x1_reg + btn_w, _btn_draw_h_end, false);

draw_set_color(col_texto_claro);
draw_text(x1_reg + btn_w/2, _btn_draw_y + btn_h/2, "Registrar");