function on_welcome(_payload) {
    // Perceba o "obj_Network." antes da variável
    obj_Network.my_id = string(_payload.my_id);
    show_debug_message(">>> [LOGIN] ID Definido: " + obj_Network.my_id);
}