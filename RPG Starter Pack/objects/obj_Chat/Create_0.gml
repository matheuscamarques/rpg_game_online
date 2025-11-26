enum CHAT_CHANNEL {
    GENERAL,
    COMBAT,
    SERVER
}


// --- Configurações Visuais ---
max_lines = 100;        // Aumentei o histórico pois agora filtramos
line_height = 18;
chat_width = 400;
chat_height = 200;
font = fnt_chat;

// Posição da janela (Fundo)
gui_x = 20;
gui_y = display_get_gui_height() - 240;

// --- Configurações das Abas ---
current_tab = CHAT_CHANNEL.GENERAL; // Começa na aba Geral
tab_width = 80;
tab_height = 25;

// Definição das Abas (Nome e ID do enum associado)
tabs = [
    { name: "Geral", type: CHAT_CHANNEL.GENERAL },
    { name: "Combate", type: CHAT_CHANNEL.COMBAT },
    { name: "Eventos", type: CHAT_CHANNEL.SERVER }
];

// --- Estados e Input ---
is_typing = false;
input_text = "";
blink_timer = 0;

// --- Armazenamento ---
// Agora usaremos APENAS UMA lista, que guardará Structs
chat_log = ds_list_create(); 

// --- Função de Adicionar Mensagem (Atualizada) ---
add_message = function(_text, _color, _channel) {
    // Cria um pacote de dados da mensagem
    var _msg_struct = {
        text: _text,
        color: _color,
        channel: _channel
    };
    
    ds_list_add(chat_log, _msg_struct);
    
    // Limpeza de antigas
    if (ds_list_size(chat_log) > max_lines) {
        ds_list_delete(chat_log, 0); // Remove a mais antiga
    }
}

// --- Testando os canais ---
add_message("Bem-vindo ao servidor!", c_yellow, CHAT_CHANNEL.GENERAL);
add_message("Eventos do Servidor", c_fuchsia, CHAT_CHANNEL.SERVER);
add_message("Eventos de Combate", c_red, CHAT_CHANNEL.COMBAT);