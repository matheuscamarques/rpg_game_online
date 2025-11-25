/// EVENTO DRAW: obj_input_login

// --- DEFINIÇÃO DA PALETA DE CORES SOMBRIA/ELIXIR ---
// Nota: GameMaker usa formato BGR (Azul, Verde, Vermelho) para hexadecimais com $
var col_elixir_roxo = $7A2C5D;  // Um roxo profundo e rico (Cor destaque)
var col_elixir_escuro = $4F1836; // Um tom mais fechado para sombras/fundos
var col_texto_claro = $E3DEDE; // Um "quase branco" levemente tingido para não cansar a vista
var col_texto_apagado = $A68B9E; // Um tom acinzentado/arroxeado para textos secundários
var col_erro_sombrio = $3333CC; // Um vermelho mais fechado para erros

// --- CONFIGURAÇÕES DE FONTE (OPCIONAL MAS RECOMENDADO) ---
// Se você tiver fontes criadas, descomente as linhas abaixo e use-as.
// Para um visual "sombrio/estoico", uma fonte serifada para o título
// e uma fonte limpa ou estilo máquina de escrever para a citação funcionam bem.

// var fonte_titulo = fnt_titulo_serif; // Exemplo
// var fonte_citacao = fnt_citacao_padrao; // Exemplo
// var fonte_ui_padrao = fnt_ui_padrao; // Exemplo


// --- DESENHAR TÍTULO E CITAÇÃO (NOVO CONTEÚDO) ---
draw_set_halign(fa_center);
draw_set_valign(fa_top);

// 1. Título do Jogo
draw_set_font(font_pt); // Descomente se tiver a fonte
draw_set_color(col_elixir_roxo);
// Desenhamos bem acima da posição y atual do objeto
draw_text_transformed(x + 100, y - 180, "Enchiridion Online", 1.5, 1.5, 0);

// 2. A Mensagem Estoica
// draw_set_font(fonte_citacao); // Descomente se tiver a fonte
draw_set_color(col_texto_apagado);
var mensagem_quote = "o Encheiridion serve não como uma introdução aos que ignoram a filosofia estoica, mas antes àqueles ja familiarizados com os princípios do Estoicismo, para que tenham uma síntese que possam sempre levar consigo e utilizar";
var altura_linha = 18; // Espaçamento entre linhas
var largura_max = 500; // Largura máxima antes de quebrar a linha
draw_text_ext(x + 100, y - 130, mensagem_quote, altura_linha, largura_max);


// --- RESTAURAR CONFIGURAÇÕES PARA A UI ---
// draw_set_font(fonte_ui_padrao); // Volta para fonte normal
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
var y_senha = y + 70;

// --- CAMPO 1: LOGIN ---
// Borda: Roxo Elixir se ativo, Apagado se inativo (Substituindo verde/branco)
if (campo_ativo == 0) draw_set_color(col_elixir_roxo); else draw_set_color(col_texto_apagado);
draw_rectangle(x, y, x + 200, y + 30, true);

// Texto e Label
draw_set_color(col_texto_claro); // Substituindo c_white
draw_text(x, y - 15, "Usuario:");
draw_text(x + 5, y + 15, login_texto);


// --- CAMPO 2: SENHA ---
// Borda: Roxo Elixir se ativo, Apagado se inativo
if (campo_ativo == 1) draw_set_color(col_elixir_roxo); else draw_set_color(col_texto_apagado);
draw_rectangle(x, y_senha, x + 200, y_senha + 30, true);

// Texto e Label
draw_set_color(col_texto_claro); // Substituindo c_white
draw_text(x, y_senha - 15, "Senha:");

// Máscara de senha com asteriscos
var senha_visual = string_repeat("*", string_length(senha_texto));
draw_text(x + 5, y_senha + 15, senha_visual);


// --- MENSAGEM DE ERRO OU SUCESSO (TOPO DO FORMULÁRIO) ---
if (msg_erro != "") {
    draw_set_halign(fa_center);
    // Se sucesso, usa o roxo elixir, se erro, usa o vermelho sombrio
    if (msg_erro == "Conta Criada! Faça Login.") {
        draw_set_color(col_elixir_roxo);
    } else {
        draw_set_color(col_erro_sombrio);
    }

    // Ajustei levemente a posição Y para não bater na citação
    draw_text(x + 100, y - 35, msg_erro);
}


// --- DESENHAR BOTÕES ---
// (Assumindo que cor_bordo e cor_bordo_hover no Create já combinam com o tema.
// Se não, substitua por col_elixir_escuro e col_elixir_roxo aqui)

var x1_log = x;
var x2_log = x + btn_w;
var y2_btn = btn_y + btn_h;

var x1_reg = x + btn_w + espaco;
var x2_reg = x + btn_w + espaco + btn_w;

// 1. BOTÃO LOGIN
if (point_in_rectangle(mouse_x, mouse_y, x1_log, btn_y, x2_log, y2_btn)) {
    draw_set_color(cor_bordo_hover);
} else {
    draw_set_color(cor_bordo);
}

draw_rectangle(x1_log, btn_y, x2_log, y2_btn, false); // false = preenchido

draw_set_color(col_texto_claro); // Texto claro no botão
draw_set_halign(fa_center);
draw_text(x1_log + (btn_w/2), btn_y + (btn_h/2), "Login");


// 2. BOTÃO REGISTER
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, btn_y, x2_reg, y2_btn)) {
    draw_set_color(cor_bordo_hover);
} else {
    draw_set_color(cor_bordo);
}

draw_rectangle(x1_reg, btn_y, x2_reg, y2_btn, false);

draw_set_color(col_texto_claro); // Texto claro no botão
draw_text(x1_reg + (btn_w/2), btn_y + (btn_h/2), "Register");


// --- INSTRUÇÃO (RODAPÉ) ---
draw_set_halign(fa_left);
draw_set_color(col_texto_apagado); // Usando a cor apagada em vez de c_gray

draw_text(x - 50, btn_y + 45, "TAB: Troca | ENTER: Confirma");