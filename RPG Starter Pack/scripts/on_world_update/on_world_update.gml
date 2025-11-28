function on_world_update(_payload) {
    // O payload agora contém uma LISTA de entidades
    var _list = _payload.entities;
    var _count = array_length(_list);
    
    // Loop para processar todos os inimigos do pacote de uma vez
    for (var i = 0; i < _count; i++) {
        var _entity_data = _list[i];
        
        // Chama a sua função antiga de update INDIVIDUAL passando os dados
        // Reutilizamos a lógica que você já criou!
        on_enemy_update(_entity_data);
    }
}