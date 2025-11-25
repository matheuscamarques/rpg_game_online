/// EVENTO CREATE: obj_selecao_char

// --- 1. ESTADO DO SISTEMA ---
estado = "LISTA"; // "LISTA" ou "CRIANDO"
slot_deletando = -1; // -1 = Ninguém. Se for 0, 1... é o índice para apagar.

// --- 2. CONFIGURAÇÃO VISUAL ---
lista_largura = 280;
lista_x = room_width - lista_largura; 
lista_y_inicial = 90; 
slot_altura = 80;     

// --- 3. SCROLL ---
scroll_y = 0;           
scroll_velocidade = 30; 
altura_total_lista = 0; 
view_altura = room_height - 100;

// --- 4. DADOS DE CRIAÇÃO ---
input_nome = "";
keyboard_string = ""; 

// Definição das Classes e Sprites
classes_nomes = ["Guerreiro", "Mago", "Ladino", "Clérigo"];

// IMPORTANTE: Substitua pelos nomes reais dos seus sprites no Asset Browser
classes_sprites = [spr_warrior_idle_down, spr_mage_idle_down, spr_rogue_idle_down, spr_clerig_idle_down]; 
classe_idx = 0; 

// --- 5. CORES ---
cor_fundo_lista = make_color_rgb(30, 30, 40); 
cor_slot_normal = make_color_rgb(50, 50, 60);
cor_slot_hover = make_color_rgb(100, 0, 30);  
cor_ui_border = c_white;

// --- 6. CONTROLE DE REDE (FIX: Inicializar para evitar crash) ---
request_load = -1;
request_create = -1;
request_delete = -1;

// --- 7. DISPARAR LOAD INICIAL ---
// Só tenta carregar se tivermos um token (segurança)
if (variable_global_exists("api_token") && global.api_token != "") {
    show_debug_message("Iniciando Load de Personagens...");
    
    var _url = global.api_url + "/characters";
    var _header = ds_map_create();
    ds_map_add(_header, "Content-Type", "application/json");
    ds_map_add(_header, "Authorization", "Bearer " + global.api_token); 

    request_load = http_request(_url, "GET", _header, "");
    ds_map_destroy(_header);
} else {
    show_debug_message("ERRO: Sem Token. Volte para o Login.");
    // room_goto(rm_login); // Opcional: Forçar volta se não tiver token
}