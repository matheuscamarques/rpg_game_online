/// EVENTO CREATE: obj_selecao_char

// --- 1. ESTADO DO SISTEMA ---
// "LISTA" = Vendo os slots | "CRIANDO" = Editando novo char
estado = "LISTA"; 

// Variável de Controle de Deleção
// -1 = Ninguém. Se for 0, 1, 2... é o índice que será apagado.
slot_deletando = -1; 

// --- 2. CONFIGURAÇÃO DA LISTA (DIREITA) ---
lista_largura = 280; // Largura da barra lateral
lista_x = room_width - lista_largura; 
lista_y_inicial = 90; // Começa abaixo do cabeçalho
slot_altura = 80;     // Altura de cada card

// --- 3. VARIÁVEIS DE SCROLL ---
scroll_y = 0;           // Posição atual
scroll_velocidade = 30; // Velocidade da rodinha
altura_total_lista = 0; // Calculado no Step
view_altura = room_height - 100; // Área visível

// --- 4. CONFIGURAÇÃO DA CRIAÇÃO (ESQUERDA) ---
input_nome = "";
keyboard_string = ""; 

// Definição das Classes (Certifique-se que os sprites existem!)
classes_nomes = ["Guerreiro", "Mago", "Ladino", "Clerigo"];
classes_sprites = [spr_player_idle_down, spr_player_idle_down, spr_player_idle_down, spr_player_idle_down]; 
classe_idx = 0; 

// --- 5. CORES & VISUAL ---
cor_fundo_lista = make_color_rgb(30, 30, 40); // Cinza escuro
cor_slot_normal = make_color_rgb(50, 50, 60);
cor_slot_hover = make_color_rgb(100, 0, 30);  // Bordô
cor_ui_border = c_white;