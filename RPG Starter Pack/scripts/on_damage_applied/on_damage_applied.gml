function on_damage_applied(_payload) {
    var _target_id = _payload.target_id;
    var _damage = _payload.damage;
    // var _attacker_id = _payload.attacker_id; 
    
    // 1. ACHA QUEM SOFREU DANO
    var _victim = noone;
    var _is_enemy = false; // Flag para ajudar a escolher a cor do texto
    
    // A. Se fui EU (Player Local)
    // Dica: string() garante que tipos não quebrem a comparação
    if (string(_target_id) == string(obj_Network.my_id)) {
        _victim = obj_Player;
    } 
    // B. Se foi OUTRO JOGADOR (Remote Player)
    else if (ds_map_exists(obj_Network.remote_players_map, _target_id)) {
        _victim = obj_Network.remote_players_map[? _target_id];
    }
    // C. --- NOVO: SE FOI UM INIMIGO (Enemy) ---
    else if (ds_map_exists(obj_Network.enemies_map, _target_id)) {
        _victim = obj_Network.enemies_map[? _target_id];
        _is_enemy = true;
    }
    
    // 2. APLICA EFEITOS
    if (_victim != noone && instance_exists(_victim)) {
        
        // --- TEXTO DE DANO ---
        // Cria na layer "Instances" (ou "Effects") para mover junto com o mapa
        var _txt = instance_create_layer(_victim.x, _victim.y - 30, "Instances", obj_DamageText);
        _txt.text = string(_damage);
        
        // --- PERSONALIZAÇÃO DE COR ---
        if (_victim == obj_Player) {
            _txt.color = c_red;     // Dano que tomei (PERIGO!)
        } 
        else if (_is_enemy) {
            _txt.color = c_white;   // Dano em monstros (Padrão RPG: Branco ou Laranja)
        } 
        else {
            _txt.color = c_yellow;  // Dano que amigos tomaram (Alerta)
        }
        
        // --- FLASH DE DANO ---
        _victim.image_blend = c_red; 
        
        // Se o objeto (Player, Remote ou Inimigo) tiver o Evento Alarm 0 configurado
        _victim.alarm[0] = 8; 
    }
}