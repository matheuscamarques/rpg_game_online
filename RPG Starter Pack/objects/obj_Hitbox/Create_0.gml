// Propriedades que serão sobrescritas por quem spawnou (o Player)
owner = noone; 
damage = 1;
knockback = 5;

// Lista para garantir que cada inimigo só toma dano 1 vez por esse ataque
hit_list = ds_list_create();

is_authoritative = false;