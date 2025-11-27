// 1. MOVIMENTO (Sobe e desacelera)
y += vsp;
vsp += gravity_force; // A gravidade faz ele parar de subir aos poucos

// 2. FADE OUT (Desaparecer)
// Só começa a diminuir o alpha quando ele já estiver menor que 1 (delay visual)
alpha -= 0.03; 

if (alpha <= 0) {
    instance_destroy();
}

// 3. ESCALA (Efeito Pop)
// Interpola o tamanho atual para o tamanho alvo (efeito elástico)
scale = lerp(scale, scale_target, 0.2);