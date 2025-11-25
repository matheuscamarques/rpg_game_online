/// EVENTO STEP: obj_InputRegister

var mouse_click = mouse_check_button_pressed(mb_left);

// Limpa erro ao digitar
if (keyboard_check_pressed(vk_anykey)) msg_erro = "";

// --- 1. ALTERNAR CAMPOS (TAB) ---
if (keyboard_check_pressed(vk_tab)) {
    campo_ativo++; 
    if (campo_ativo > 3) campo_ativo = 0; // Volta pro primeiro
    
    // Restaura texto correto
    if (campo_ativo == 0) keyboard_string = email_texto;
    if (campo_ativo == 1) keyboard_string = user_texto;
    if (campo_ativo == 2) keyboard_string = senha_texto;
    if (campo_ativo == 3) keyboard_string = check_texto;
}

// --- 2. SELEÇÃO POR MOUSE (4 Áreas) ---
// Alturas: y, y+70, y+140, y+210
if (mouse_click) {
    if (point_in_rectangle(mouse_x, mouse_y, x, y, x+200, y+30)) { campo_ativo=0; keyboard_string=email_texto; }
    if (point_in_rectangle(mouse_x, mouse_y, x, y+70, x+200, y+70+30)) { campo_ativo=1; keyboard_string=user_texto; }
    if (point_in_rectangle(mouse_x, mouse_y, x, y+140, x+200, y+140+30)) { campo_ativo=2; keyboard_string=senha_texto; }
    if (point_in_rectangle(mouse_x, mouse_y, x, y+210, x+200, y+210+30)) { campo_ativo=3; keyboard_string=check_texto; }
}

// --- 3. CAPTURA DE TEXTO ---
var txt = string_copy(keyboard_string, 1, 20); // Limite de 20 chars
if (campo_ativo == 0) email_texto = txt;
if (campo_ativo == 1) user_texto = txt;
if (campo_ativo == 2) senha_texto = txt;
if (campo_ativo == 3) check_texto = txt;

// --- 4. BOTÕES ---
var x1_voltar = x;
var x2_voltar = x + btn_w;
var x1_reg = x + btn_w + espaco;
var x2_reg = x + btn_w + espaco + btn_w;
var y2_btn = btn_y + btn_h;

// BOTÃO VOLTAR (Vai para rm_login)
if (point_in_rectangle(mouse_x, mouse_y, x1_voltar, btn_y, x2_voltar, y2_btn) && mouse_click) {
    room_goto(rm_login);
}

// BOTÃO REGISTRAR
if (point_in_rectangle(mouse_x, mouse_y, x1_reg, btn_y, x2_reg, y2_btn) && mouse_click) {
    
    // 1. Validação Local Básica
    if (email_texto == "" || user_texto == "" || senha_texto == "") {
        msg_erro = "Preencha todos os campos!";
        shake_timer = 10;
    } 
    else if (senha_texto != check_texto) {
        msg_erro = "As senhas não coincidem!";
        shake_timer = 10;
    } 
    else {
        // 2. PREPARAR O JSON PARA O PHOENIX
        // O backend espera: %{"username" => ..., "email" => ..., "password" => ...}
        var _body = {
            username: user_texto,
            email: email_texto,
            password: senha_texto
        };
        
        var _json_str = json_stringify(_body);
        
        // 3. CONFIGURAR HEADER (Não precisa de Token aqui, é rota pública)
        var _header = ds_map_create();
        ds_map_add(_header, "Content-Type", "application/json");
        
        // 4. DISPARAR REQUISIÇÃO
        // URL: http://localhost:4000/api/register
        request_register = http_request(global.api_url + "/register", "POST", _header, _json_str);
        
        ds_map_destroy(_header);
        
        // Feedback imediato enquanto espera
        msg_erro = "Enviando dados...";
	}
}

// --- SHAKE ---
if (shake_timer > 0) { x = x_original + random_range(-5, 5); shake_timer--; } 
else { x = x_original; }