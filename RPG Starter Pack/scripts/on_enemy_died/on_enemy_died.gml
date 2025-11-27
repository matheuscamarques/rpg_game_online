function on_enemy_died(_payload) {
    var _id = _payload.id;
    
    // Remove do mapa de inimigos
    if (ds_map_exists(obj_Network.enemies_map, _id)) {
        var _inst = obj_Network.enemies_map[? _id];
        
        if (instance_exists(_inst)) {
            // Efeito de morte (Fumaça, particulas)
            // instance_create_layer(_inst.x, _inst.y, "Effects", obj_DeathEffect);
            
            instance_destroy(_inst);
        }
        
        ds_map_delete(obj_Network.enemies_map, _id);
    }
}