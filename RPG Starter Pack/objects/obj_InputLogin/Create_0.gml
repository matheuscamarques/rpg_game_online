/// EVENTO CREATE: obj_input_login

// --- 1. CENTRALIZAÇÃO AUTOMÁTICA ---
// A caixa de texto tem 200px de largura.
// Para centralizar: (Largura da Sala / 2) - (Metade da Largura da Caixa)
x = (room_width / 2) - 100; 

// Para a altura, subimos um pouco (-80) para dar espaço aos botões embaixo
y = (room_height / 2) - 80; 


// --- 2. VARIÁVEIS DE CONTROLE ---
login_texto = "";
senha_texto = "";
campo_ativo = 0;      // 0 = Login, 1 = Senha
keyboard_string = ""; // Limpa o buffer do teclado do sistema


// --- 3. DADOS DE LOGIN (SIMULAÇÃO) ---
usuario_correto = global.db_user;
senha_correta = global.db_pass;


// --- 4. FEEDBACK VISUAL ---
msg_erro = "";
shake_timer = 0;

// IMPORTANTE: Salvamos o x_original DEPOIS de centralizar a tela.
// Se salvar antes, o efeito de tremer vai teleportar a caixa para o canto.
x_original = x; 


// --- 5. CORES E BOTÕES ---
// Cor Personalizada (Bordô)
cor_bordo = make_color_rgb(100, 0, 30); 
cor_bordo_hover = make_color_rgb(140, 20, 50); 

// Configuração de layout dos botões
btn_y = y + 120;        // Posição Y (abaixo das caixas de texto)
btn_w = 95;             // Largura de cada botão
btn_h = 30;             // Altura do botão
espaco = 10;            // Espaço entre o botão Login e Register