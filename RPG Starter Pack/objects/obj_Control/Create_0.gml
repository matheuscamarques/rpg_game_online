// Inicializa as variáveis que vamos usar no jogo todo
global.nome_jogador = "";        // Vai guardar o texto do login
global.personagem_tipo = 0;      // 0 = nenhum, 1 = herói A, 2 = herói B
randomize();  

// Adicione isto no Create do obj_controle
global.db_email = "";
global.db_user = "admin"; // Usuário inicial
global.db_pass = "1234";  // Senha inicial
// Garante que coisas aleatórias sejam sempre diferentes

// Lista de Personagens (Começa vazia)
global.personagens = []; 
// Exemplo de como um personagem será salvo lá dentro:
// { nome: "Matheus", classe: "Guerreiro", sprite: spr_guerreiro, nivel: 1 }

// Personagem atual selecionado para jogar
global.char_ativo = -1;

global.api_url = "http://localhost:4000/api"; // Ajuste se for diferente
global.api_token = ""; // Onde guardaremos o token "Bearer ..."
global.personagens = []; 
