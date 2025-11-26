/// @desc Função que processa a mensagem recebida e manda para o obj_chat
function on_chat_message(_payload) {
    // Verificamos se o chat existe antes de tentar adicionar
    if (!instance_exists(obj_Chat)) return;

    // 1. Extrair dados do Payload (vindo do Elixir)
    // Supondo que o Elixir mande: %{text: "Olá", type: "global", sender: "Matheus"}
    var _text = _payload.text; 
    var _type_str = _payload.type; // string: "global", "combat", "server"
    var _sender = variable_struct_exists(_payload, "sender") ? _payload.sender : "Sistema";

    // 2. Definir Cor e Aba baseados no tipo
    var _color = c_white;
    var _channel = CHAT_CHANNEL.GENERAL;

    switch (_type_str) {
        case "global":
            _color = c_white;
            _channel = CHAT_CHANNEL.GENERAL;
            _text = _sender + ": " + _text; // Adiciona o nome de quem falou
            break;
            
        case "combat":
            _color = c_red;
            _channel = CHAT_CHANNEL.COMBAT;
            // Combate geralmente não precisa de "sender" se o texto já for descritivo
            break;
            
        case "server":
            _color = c_yellow;
            _channel = CHAT_CHANNEL.SERVER;
            _text = "[SERVER]: " + _text;
            break;
    }

    // 3. Mandar para a GUI
    obj_Chat.add_message(_text, _color, _channel);
}