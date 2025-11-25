/// EVENTO CREATE: obj_InputRegister

// --- 1. CENTRALIZAÇÃO ---
x = (room_width / 2) - 100; 
y = (room_height / 2) - 150; // Subi mais porque tem 4 campos

// --- 2. VARIÁVEIS DOS CAMPOS ---
email_texto = "";
user_texto = "";
senha_texto = "";
check_texto = ""; // Confirmação de senha

campo_ativo = 0; // 0=Email, 1=User, 2=Senha, 3=Check
keyboard_string = ""; 

// --- 3. FEEDBACK ---
msg_erro = "";
shake_timer = 0;
x_original = x; 

// --- 4. CORES E BOTÕES ---
cor_bordo = make_color_rgb(100, 0, 30); 
cor_bordo_hover = make_color_rgb(140, 20, 50); 

// Botões ficam abaixo do 4º campo (4 * 70px de altura aprox)
btn_y = y + 300; 
btn_w = 95;             
btn_h = 30;             
espaco = 10;

// Adicione esta variável para controlar a requisição HTTP
request_register = -1;