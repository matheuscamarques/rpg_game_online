// Alarm 0 (GC Otimizado para HTML5)
var _player = instance_find(obj_Player, 0);
if (!instance_exists(_player)) { alarm[0] = 60; exit; }

var _buffer = 1200; // Margem de segurança

// 1. DESATIVA TUDO QUE ESTÁ LONGE (Muito rápido)
instance_deactivate_object(obj_EnemyParent);

// 2. ATIVA APENAS O QUE ESTÁ PERTO (Region Activation)
// Ativa um retângulo ao redor do player
instance_activate_region(_player.x - _buffer, _player.y - _buffer, _buffer*2, _buffer*2, true);

// 3. (Opcional) A cada X segundos, aí sim faça um loop para destruir 
// o que está desativado há muito tempo para liberar RAM.

alarm[4] = garbage_collect_interval; // Pode rodar mais frequente agora pois deactivate é nativo C++