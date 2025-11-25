/// @function on_welcome(payload)
function on_welcome(_payload) {
    var _id = _payload.my_id;
    
    show_debug_message(">>> [WELCOME] Sou o ID: " + string(_id));
    
    // Salva meu ID na rede
    obj_Network.my_id = string(_id);
    
    // Configura o jogador local (se já existir)
    if (instance_exists(obj_Player)) {
        obj_Player.my_network_id = string(_id);
    } 
    else {
        // Se ainda não existir, cria o jogador local
        var _p = instance_create_layer(200, 200, "Instances", obj_Player);
        _p.my_network_id = string(_id);
        // Define o sprite correto
        _p.sprite_index = global.char_ativo.sprite;
    }
}