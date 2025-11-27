// Posição alvo (onde o servidor disse que ele está)
target_x = x;
target_y = y;

// Identidade
network_id = "";
char_info = pointer_null;
remote_state = 0;

// --- NOVO: Controle da Hitbox Remota ---
my_hitbox = noone; // Guarda o ID da hitbox criada
facing_direction = 270; // Começa olhando para baixo (ou 0)
attack_timer = 0;
attack_timer_max = 20;
