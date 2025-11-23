function phoenix_send(_socket, _topic, _event, _payload){
    // 1. Proteção básica
    if (!instance_exists(obj_Network)) return;
    
    // 2. Incrementa referência
    obj_Network.ref_count++;
    var _ref = string(obj_Network.ref_count);
    
    // 3. Monta o Array (Protocolo Phoenix V2)
    var _msg_array = array_create(5);
    _msg_array[0] = _ref;         // join_ref
    _msg_array[1] = _ref;         // ref
    _msg_array[2] = _topic;       // topic
    _msg_array[3] = _event;       // event
    _msg_array[4] = _payload;     // payload
    
    // 4. Converte para JSON
    var _json_str = json_stringify(_msg_array);
    
    // --- CORREÇÃO DO CRASH HTML5 ---
    
    // Em vez de calcular tamanho antes, criamos um buffer pequeno que CRESCE (buffer_grow)
    // Isso evita erros de cálculo de bytes vs caracteres no HTML5
    var _buff = buffer_create(256, buffer_grow, 1);
    
    // Garante que o cursor está no zero
    buffer_seek(_buff, buffer_seek_start, 0);
    
    // Escreve a string (O buffer vai aumentar de tamanho sozinho se precisar)
    buffer_write(_buff, buffer_text, _json_str);
    
    // Pega o tamanho REAL do que foi escrito
    var _size = buffer_tell(_buff);
    
    // LOG DE SEGURANÇA (Para ver no console se deu certo)
    show_debug_message(">>> [OUT] Enviando (" + string(_size) + " bytes): " + _json_str);
    
    // Envia usando o tamanho calculado pós-escrita
    // IMPORTANTE: O socket deve ser válido. O log mostrou que seu socket é 0. 
    // Em HTML5, 0 é um ID válido, mas verifique se _socket não é undefined aqui.
    if (!is_undefined(_socket)) {
        network_send_raw(_socket, _buff, _size);
    } else {
        show_debug_message(">>> [ERRO] Tentativa de envio em socket undefined");
    }
    
    // Limpa a memória
    buffer_delete(_buff);
}