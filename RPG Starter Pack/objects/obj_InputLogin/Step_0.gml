/// EVENTO STEP: obj_input_login

// --- 1. CONFIGURAÇÕES INICIAIS ---
var y_senha = y + 70; // Mesma altura usada no Draw
var mouse_click = mouse_check_button_pressed(mb_left);

// Limpa mensagem de erro se o jogador começar a digitar
if (keyboard_check_pressed(vk_anykey)) {
    msg_erro = "";
}

// --- 2. ALTERNAR FOCO (TAB ou MOUSE) ---

// Via TAB
if (keyboard_check_pressed(vk_tab)) {
    campo_ativo = !campo_ativo;
    // Restaura o texto do buffer para continuar digitando sem perder o que já tinha
    if (campo_ativo == 0) keyboard_string = login_texto;
    else keyboard_string = senha_texto;
}

// Via MOUSE (Clique na caixa de Login)
if (point_in_rectangle(mouse_x, mouse_y, x, y, x + 200, y + 30)) {
    if (mouse_click) {
        campo_ativo = 0;
        keyboard_string = login_texto;
    }
}

// Via MOUSE (Clique na caixa de Senha)
if (point_in_rectangle(mouse_x, mouse_y, x, y_senha, x + 200, y_senha + 30)) {
    if (mouse_click) {
        campo_ativo = 1;
        keyboard_string = senha_texto;
    }
}

// --- 3. CAPTURA DE TEXTO ---
if (campo_ativo == 0) {
    // Limita caracteres se quiser (opcional)
    if (string_length(keyboard_string) > 15) keyboard_string = string_copy(keyboard_string, 1, 15);
    login_texto = keyboard_string;
} else {
    if (string_length(keyboard_string) > 15) keyboard_string = string_copy(keyboard_string, 1, 15);
    senha_texto = keyboard_string;
}

// --- 4. LÓGICA DOS BOTÕES (LOGIN E REGISTER) ---

// Coordenadas dos botões (baseadas nas variáveis do Create)
var x1_log = x;
var x2_log = x + btn_w;
var y1_btn = btn_y;
var y2_btn = btn_y + btn_h;

var x1_reg = x + btn_w + espaco;
var x2_reg = x + btn_w + espaco + btn_w;

// Verifica gatilhos de Login (Clicar no botão OU apertar Enter)
var clicou_login = point_in_rectangle(mouse_x, mouse_y, x1_log, y1_btn, x2_log, y2_btn) && mouse_click;
var apertou_enter = keyboard_check_pressed(vk_enter);

// --- AÇÃO: TENTAR LOGIN ---
if (clicou_login || apertou_enter) {
    if (login_texto == usuario_correto && senha_texto == senha_correta) {
        // SUCESSO!
        global.nome_jogador = login_texto;
        room_goto(rm_select); 
    } 
    else {
        // ERRO!
        msg_erro = "Usuário ou Senha incorretos!";
        shake_timer = 10;
        senha_texto = "";       // Limpa senha visual
        keyboard_string = "";   // Limpa buffer do teclado
        campo_ativo = 1;        // Foca na senha
    }
}

// --- AÇÃO: REGISTRAR (Clicar no botão Register) ---
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, y1_btn, x2_reg, y2_btn) && mouse_click) {
    room_goto(rm_register); 
}

// --- 5. EFEITO SHAKE (TREMEDEIRA) ---
if (shake_timer > 0) {
    x = x_original + random_range(-5, 5); 
    shake_timer -= 1; 
} else {
    x = x_original; 
}