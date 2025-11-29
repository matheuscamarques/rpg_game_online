function on_damage_missed(_payload) {
    var _target_id = _payload.target_id;
    // Não precisamos de _damage aqui, pois foi zero/miss

    // 1. ACHA QUEM "ESQUIVOU" (O ALVO ORIGINAL)
    // (Essa lógica é idêntica à de damage_applied para garantir consistência)
    var _victim = noone;
    var _is_enemy = false; 

    // A. Se fui EU (Player Local)
    if (string(_target_id) == string(obj_Network.my_id)) {
        _victim = obj_Player;
    } 
    // B. Se foi OUTRO JOGADOR (Remote Player)
    else if (ds_map_exists(obj_Network.remote_players_map, _target_id)) {
        _victim = obj_Network.remote_players_map[? _target_id];
    }
    // C. SE FOI UM INIMIGO
    else if (ds_map_exists(obj_Network.enemies_map, _target_id)) {
        _victim = obj_Network.enemies_map[? _target_id];
        _is_enemy = true;
    }
    
    // 2. APLICA EFEITOS VISUAIS DE "MISS"
    if (_victim != noone && instance_exists(_victim)) {
        
        // --- TEXTO DE MISS ---
        // Cria o texto flutuante
        var _txt = instance_create_layer(_victim.x, _victim.y - 30, "Instances", obj_DamageText);
        
        // Define o texto. Opções: "MISS", "DODGE", "ERROU"
        _txt.text = "MISS"; 
        
        // --- PERSONALIZAÇÃO DE COR ---
        // Diferente do dano, aqui queremos indicar neutralidade ou agilidade
        if (_victim == obj_Player) {
            // Se EU esquivei, talvez um azul ou ciano para indicar "Boa!"
            _txt.color = c_aqua;  
        } 
        else {
            // Se ataquei e errei (no inimigo ou outro player), cinza para indicar ineficácia
            _txt.color = c_ltgray; 
        }
        
        // --- SEM FLASH DE DANO ---
        // IMPORTANTE: Não pintamos de vermelho (_victim.image_blend) 
        // para o cérebro do jogador não registrar como hit.
		 // --- FLASH DE DANO ---
        _victim.image_blend = c_aqua; 
        
        // Se o objeto (Player, Remote ou Inimigo) tiver o Evento Alarm 0 configurado
        _victim.alarm[0] = 8; 
        // Opcional: Efeito sonoro de "woosh" ou vento
        // audio_play_sound(snd_Miss, 10, false);
    }
}