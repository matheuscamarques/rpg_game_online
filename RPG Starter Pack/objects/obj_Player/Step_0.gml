// 1. EXECUTA A MÁQUINA DE ESTADOS
switch (state) {
    case STATES.FREE:   state_free(); break;
    case STATES.ATTACK: state_attack(); break;
}

// -------------------------
// 2. NETWORKING
// -------------------------
if (network_timer > 0) network_timer--;

// Detecta mudanças
var _pos_changed   = (x != xprevious || y != yprevious);
var _spr_changed   = (sprite_index != last_sprite);
var _state_changed = (state != last_state); // <--- NOVO: Detecta se entrou/saiu do ataque

// GATILHO: Envia se mudou Sprite, Posição OU ESTADO
// Adicionamos "_state_changed" na verificação prioritária (sem timer)
if (_spr_changed || _state_changed || (_pos_changed && network_timer <= 0)) {
    
    var payload = {
        x: x,
        y: y,
        spr: sprite_index,
        image_index: image_index,
        state: state,
		face: facing_direction
    };

    if (obj_Network.connected) {
        // Dica: Se o Phoenix esperar strings nas chaves, garanta que o parse lá suporte isso
        phoenix_send(obj_Network.socket, "room:lobby", "move", payload);
    }

    // Atualiza os "Last"
    last_sprite = sprite_index;
    last_state  = state; // <--- Atualiza o histórico do estado
    network_timer = 2; 
}

// Atualiza posições anteriores
xprevious = x;
yprevious = y;