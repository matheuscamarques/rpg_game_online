/// EVENTO STEP: obj_input_login

// --- 1. CONFIGURAÇÕES INICIAIS ---
var y_senha = y + 70;
var mouse_click = mouse_check_button_pressed(mb_left);

// Limpa mensagem se digitar
if (keyboard_check_pressed(vk_anykey)) {
    msg_erro = "";
}

// --- 2. ALTERNAR FOCO (TAB ou MOUSE) ---
// (Mantive idêntico ao seu)
if (keyboard_check_pressed(vk_tab)) {
    campo_ativo = !campo_ativo;
    if (campo_ativo == 0) keyboard_string = login_texto;
    else keyboard_string = senha_texto;
}

if (point_in_rectangle(mouse_x, mouse_y, x, y, x + 200, y + 30)) {
    if (mouse_click) { campo_ativo = 0; keyboard_string = login_texto; }
}

if (point_in_rectangle(mouse_x, mouse_y, x, y_senha, x + 200, y_senha + 30)) {
    if (mouse_click) { campo_ativo = 1; keyboard_string = senha_texto; }
}

// --- 3. CAPTURA DE TEXTO ---
if (campo_ativo == 0) {
    if (string_length(keyboard_string) > 15) keyboard_string = string_copy(keyboard_string, 1, 15);
    login_texto = keyboard_string;
} else {
    if (string_length(keyboard_string) > 15) keyboard_string = string_copy(keyboard_string, 1, 15);
    senha_texto = keyboard_string;
}

// --- 4. LÓGICA DOS BOTÕES ---
var x1_log = x;
var x2_log = x + btn_w;
var y1_btn = btn_y;
var y2_btn = btn_y + btn_h;

var x1_reg = x + btn_w + espaco;
var x2_reg = x + btn_w + espaco + btn_w;

var clicou_login = point_in_rectangle(mouse_x, mouse_y, x1_log, y1_btn, x2_log, y2_btn) && mouse_click;
var apertou_enter = keyboard_check_pressed(vk_enter);

// --- AÇÃO: TENTAR LOGIN (AGORA COM API) ---
if (clicou_login || apertou_enter) {
    
    // Validação básica antes de chamar o servidor
    if (login_texto == "" || senha_texto == "") {
        msg_erro = "Preencha os campos!";
        shake_timer = 10;
    } 
    else {
        msg_erro = "Conectando..."; // Feedback visual imediato
        
        // 1. Monta o JSON para o Phoenix
        var _body = {
            username: login_texto,
            password: senha_texto
        };
        var _json_str = json_stringify(_body);
        
        // 2. Cria o Cabeçalho
        var _header = ds_map_create();
        ds_map_add(_header, "Content-Type", "application/json");
        
        // 3. Envia o POST para /api/login e guarda o ID da requisição
        // Certifique-se que global.api_url está definido no obj_controle (ex: "http://localhost:4000/api")
        request_login = http_request(global.api_url + "/login", "POST", _header, _json_str);
        
        ds_map_destroy(_header);
    }
}

// --- AÇÃO: IR PARA REGISTRO ---
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, y1_btn, x2_reg, y2_btn) && mouse_click) {
    room_goto(rm_register); 
}

// --- 5. EFEITO SHAKE ---
if (shake_timer > 0) {
    x = x_original + random_range(-5, 5); 
    shake_timer -= 1; 
} else {
    x = x_original; 
}