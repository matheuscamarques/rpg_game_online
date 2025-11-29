event_inherited();
// --- MOVIMENTO E INTERPOLAÇÃO ---
target_x = x;
target_y = y;
smoothing = 0.1; // <--- FALTAVA ISSO (Define a suavidade do lerp, 10%)

// --- IDENTIDADE ---
network_id = "";
char_info = pointer_null; // Começa vazio (o Draw Event deve tratar isso com is_struct)

// --- VISUAL ---
image_speed = 1; // <--- FALTAVA ISSO (Para a animação rodar)
depth = -y;      // (Opcional, mas bom inicializar)

// --- COMBATE (VISUAL) ---
remote_state = 0;       // 0=Livre, 1=Atacando
my_hitbox = noone;      // Guarda o ID da hitbox visual
facing_direction = 270; // Direção padrão (Baixo)

// --- TIMERS ---
attack_timer = 0;
attack_timer_max = 20;  // Duração da animação de ataque