// 1. SE O DONO SUMIU, EU SUMO
if (!instance_exists(owner)) {
    instance_destroy();
    exit;
}

// 2. ACOMPANHA O DONO (Opcional, mas bom para lag visual)
// x = owner.x + lengthdir_x(20, owner.facing_direction);
// y = owner.y + lengthdir_y(20, owner.facing_direction);

// 3. SEGURANÇA DE REDE
// Se eu sou apenas uma cópia visual (criada pelo obj_RemotePlayer),
// eu NÃO devo processar colisão de rede. Paro aqui.
if (is_authoritative == false) {
    
    // (Opcional) Feedback visual local se bater em mim mesmo
    // if (place_meeting(x, y, obj_Player)) { ... toca som de bloqueio ... }
    
    exit; 
}

// =========================================================
// LÓGICA DE COLISÃO (SÓ RODA SE FOR AUTORITATIVO)
// =========================================================

var _list_now = ds_list_create();
// Verifica colisão APENAS com inimigos remotos (ou monstros)
var _hits = instance_place_list(x, y, par_Damageable, _list_now, false);

if (_hits > 0) {
    for (var i = 0; i < _hits; i++) {
        var _enemy_inst = _list_now[| i];
        
        // Se ainda não atingiu este alvo neste ataque
        if (ds_list_find_index(hit_list, _enemy_inst) == -1) {
            
            ds_list_add(hit_list, _enemy_inst); // Marca como processado
            
            // --- ENVIO PARA O BACKEND ---
            var _target_id = _enemy_inst.network_id; 
            
            if (_target_id != "") {
                var _payload = {
                    target_id: _target_id,
					hit_x: x,
					hit_y: y,
                    atk_x: owner.x,  // Para validação de distância no server
                    atk_y: owner.y,
                    dmg_type: "slash"
                };
                
                // Envia o hit para o servidor validar e broadcastar
                phoenix_send(obj_Network.socket, "room:lobby", "attack_hit", _payload);
            }
            
            // --- FEEDBACK VISUAL IMEDIATO (Client-Side Prediction) ---
            // Cria faísca/sangue no local do impacto
            // instance_create_layer(_enemy_inst.x, _enemy_inst.y, "Effects", obj_HitSpark);
            
            // NOTA: NÃO tiramos vida aqui. Esperamos o pacote "damage_applied" voltar.
        }
    }
}
ds_list_destroy(_list_now);