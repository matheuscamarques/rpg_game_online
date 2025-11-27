// Se eu (RemotePlayer) for destruído, levo minha hitbox junto
if (instance_exists(my_hitbox)) {
    instance_destroy(my_hitbox);
}