# Nyakuza — ondas, KOs e classes de inimigos

Entrega baseada no ZIP enviado, com foco em `TesteRefatorado`. Engine usada na validação: **Godot 4.7 stable**, Linux, execução headless. Os modelos, animações e texturas existentes foram preservados.

## 1. Análise do projeto

A base já separa movimento, habilidades, defesa, dash e combo aéreo em controladores. O combate já oferece uma sequência terrestre de três golpes, launcher, perseguição aérea com Q, sequência aérea, slam com onda de choque, guarda e perfect guard. Isso é uma base útil para o mini musou: não foi necessário trocar todo o sistema.

As principais lacunas eram a ausência de um encontro com início/fim, os cinco inimigos fixos da cena e a falta de classes configuráveis. Também havia problemas de temporização/cancelamento e trabalho de IA que crescia muito com o número de inimigos.

O GDD define pinguins fracos/lentos com AOE, raposas médias/rápidas e pandas-vermelhos resistentes com ataques rápidos e fracos. Esses papéis foram implementados. Cookie/boss, ataque pesado dedicado e ataque musou não foram implementados nesta etapa.

## 2. Log de mudanças

### Ondas e KOs

- Criado `Waves/wave_director.gd`, integrado em `Scene/CombatScene.tscn`.
- Criados quatro recursos `Waves/Definitions/wave_01.tres` a `wave_04.tres`, com composição, intervalo de entrada e descanso editáveis.
- Os cinco inimigos fixos foram substituídos por oito `Marker3D` em `SpawnPoints` e pelo diretor de ondas.
- Entradas graduais: uma tentativa a cada 0,3 s; máximo padrão de 16 inimigos vivos. O restante fica na fila.
- Cada tentativa verifica distância do jogador, chão e espaço livre para uma cápsula. Um ponto bloqueado não consome a fila; o diretor tenta novamente e mostra uma indicação na HUD.
- A próxima onda só começa quando não há inimigos vivos nem pendentes. Há 2 s antes da primeira e 4 s entre ondas.
- A HUD mostra KOs, vivos, inimigos a chegar, número/título da onda, intervalo, vitória e interrupção por morte.
- KO vem do sinal de morte, uma vez por inimigo. `queue_free()` sem morte não concede KO. A remoção externa libera a vaga e não bloqueia o encontro.
- A morte do jogador interrompe novas entradas e encerra a progressão. Reiniciar a cena zera os contadores.

| Onda | Pinguins | Raposas | Pandas-vermelhos | Total |
|---|---:|---:|---:|---:|
| Primeiro contato | 6 | 2 | 0 | 8 |
| Reforços do clã | 7 | 4 | 1 | 12 |
| Cerco | 10 | 6 | 2 | 18 |
| Última resistência | 12 | 8 | 4 | 24 |
| **Total** | **35** | **20** | **7** | **62** |

### Classes de inimigos

Criados `EnemyProfile`, três recursos em `Enemy/Profiles` e três cenas herdadas de `Enemy.tscn`. A lógica de reação aérea continua compartilhada; os papéis são definidos pelos dados e pelo tipo de ataque.

| Classe | Vida | Velocidade | Dano | Preparação | Comportamento |
|---|---:|---:|---:|---:|---|
| Pinguim | 60 | 2,6 m/s | 10 | 0,90 s | AOE de raio 2,7 m, aviso circular no chão; placeholder azul |
| Raposa | 70 | 4,8 m/s | 8 | 0,38 s | Aproximação mais rápida e golpe frontal; placeholder laranja |
| Panda-vermelho | 160 | 3,2 m/s | 4 | 0,26 s | Golpes frequentes; recebe 55% da duração do stagger e 45% do empurrão terrestre; placeholder vermelho |

- O pinguim mostra um anel antes e durante a janela de ataque. Acertá-lo durante a preparação interrompe o ataque e remove o aviso.
- O AOE verifica distância horizontal e altura. Não acerta um jogador que esteja longe acima do inimigo.
- Todos continuam suscetíveis a launcher, juggle, slam e parry. O panda é resistente sem bloquear a mecânica central do jogo.
- A vida do pinguim permite sobreviver aos 44 pontos do combo terrestre padrão e ser lançado; não é eliminado automaticamente pelo terceiro golpe.
- Os recursos são compartilhados, mas os valores são copiados para cada instância ao iniciar. A vida atual nunca é escrita no recurso compartilhado.

### Correções de combate e controle

- `SkillsContainer.end_timer` passou a ser `one_shot`: o temporizador antigo repetia a transição de fim do ataque.
- Os temporizadores de término são preparados antes do sinal de recuperação, evitando que um callback inicie um golpe e receba um término antigo logo depois.
- Durações nulas dos temporizadores de habilidade recebem um mínimo positivo.
- Cancelar um ataque agora invalida também o dash atrasado desse golpe. Guarda e subida aérea não recebem mais um impulso antigo depois de assumirem o controle.
- Cliques durante a subida aérea ficam aguardando o hover, sem substituir a pose de subida por um ataque prematuro.
- A renovação da suspensão aérea fica restrita a inimigos próximos, em vez de manter suspensos todos os inimigos da cena.
- Ao morrer, o jogador cancela golpe, buffer de ataque, hitbox e guarda. Não continua causando dano com um ataque pendente.
- A hurtbox de um inimigo morto é bloqueada imediatamente, antes da atualização diferida da física. Isso impede hits e números de combo em cadáveres ainda presentes na lista de sobreposição.
- Hit-stop e slow-motion de parry agora usam `CombatTimeEffects`, que aplica a menor escala ainda ativa e restaura a escala anterior quando os efeitos terminam. Um efeito não encerra o outro antecipadamente.
- Corrigida a indentação da atualização de FOV em `camera_controller.gd`: o comando estava depois de um `return`, inacessível.
- Limitado o peso da interpolação de velocidade a 0–1, evitando extrapolação em frames longos; velocidade vertical interna negativa é zerada ao tocar o chão.
- Pulo bloqueado durante ataque/esquiva não consome mais a contagem de pulos aéreos.
- Vida ignora dano/cura negativos ou nulos. Referências de animação do inimigo são verificadas antes do uso, facilitando trocar placeholders.
- **F5** reinicia a partida, no lugar de R; R fica livre para um futuro musou. **Esc** libera o cursor; clique captura novamente.

### Otimizações

- A separação da multidão usa uma grade espacial reconstruída a cada 0,12 s. Cada inimigo consulta células próximas, sem percorrer toda a horda a cada frame. Cenas sem diretor mantêm um fallback limitado em frequência.
- A física dos corpos foi separada da detecção de golpes: mundo na camada 1, jogador na 2, inimigos na 3; jogador/inimigos colidem fisicamente com o mundo. As hurtboxes continuam nas camadas 4 e 5. A separação suave evita empilhamento entre inimigos. O jogador pode atravessar a multidão sem ficar bloqueado pelos corpos.
- Shader das barras de vida compartilhado em `Enemy/health_bar.gdshader`, em vez de recompilar uma cópia por inimigo. Cada barra mantém seu próprio valor de vida.
- Duração do cadáver antes de afundar reduzida de 4 s para 1,5 s; o desaparecimento leva mais 1,2 s.
- Números de dano limitados a 48 simultâneos. A supressão de um popup não altera o dano.
- A barra de vida do jogador substitui o tween anterior quando recebe nova atualização, evitando animações concorrentes.
- A HUD consulta as contagens mantidas pelo diretor; no modo sem diretor usa a contagem do grupo, sem criar uma lista inteira.

Não há promessa de ganho específico em FPS: a validação foi funcional/headless, sem benchmark de GPU ou do teu computador. O limite de 16 vivos é um ponto inicial de balanceamento e desempenho, ajustável.

### Projeto e importação

- `project.godot` agora inicia `TesteRefatorado/Scene/CombatScene.tscn`. Antes, F5 abria `Scenes/node_3d.tscn`, o protótipo antigo.
- Desativada a importação direta de `.blend` (`filesystem/import/blender/enabled=false`). A katana tinha um arquivo-fonte Blender sem referência nas cenas; sua importação impedia a importação headless sem Blender configurado. Os `.glb`, cenas e malhas já usados continuam funcionando.
- Ajustado o retorno de `_get_property_list()` em `GPUTrail-main/GPUTrail3D.gd` para `Array[Dictionary]`, conforme exigido pela engine utilizada.
- O ZIP de entrega não inclui `.godot` nem `.git`. A Godot regenera o cache. Os assets e os protótipos antigos foram mantidos.

## 3. Como aplicar na Godot

### Opção recomendada: projeto completo

1. Mantém uma cópia do teu projeto atual antes de substituir qualquer arquivo local.
2. Extrai `Nyakuza.zip` em uma **nova pasta**. Dentro haverá `Nyakuza/project.godot` e o one pager na raiz do ZIP.
3. Abre a Godot **4.7** e usa **Importar → selecionar `project.godot`**. Aguarda a reimportação dos assets. Não é necessário configurar Blender para este protótipo.
4. Abre `res://TesteRefatorado/Scene/CombatScene.tscn`.
5. Pressiona **F6** para testar essa cena ou **F5** no editor para iniciar o projeto. Ambos devem abrir o combate refatorado.
6. Após cerca de 2 s, começa a primeira onda. Confere os contadores no topo da tela. Ao derrotar as quatro ondas, aparece vitória.

A cena já tem o diretor, as referências, os marcadores e a HUD conectados. Não precisas criar nós ou conectar sinais manualmente para jogar esta versão.

### Alternativa: aplicar somente as mudanças

`Nyakuza_patch.zip` contém apenas os arquivos novos/alterados, documentação e teste. Extraia sobre uma **cópia da versão exata enviada**, alinhando a pasta `Nyakuza` com a raiz do projeto. Aceite substituir os arquivos correspondentes. Não crie `Nyakuza/Nyakuza` por engano. O patch não é um projeto independente: depende dos modelos, texturas e demais assets originais.

Se já modificaste localmente os mesmos scripts ou `CombatScene.tscn`, compara com `ARQUIVOS_ALTERADOS.txt` antes de sobrescrever. Reabre o editor para registrar as novas classes e recursos.

### Ajustar ondas

Na árvore de `CombatScene`, seleciona **WaveDirector**:

- **Max Alive:** teto de inimigos vivos (16 por padrão).
- **Initial Delay:** espera inicial.
- **Min Player Distance:** distância mínima para entrar um inimigo.
- **Spawn Jitter:** dispersão ao redor dos marcadores.
- **Waves:** lista de recursos `WaveDefinition`, em ordem.
- **Penguin Scene / Fox Scene / Red Panda Scene:** cenas herdadas dos inimigos.
- **Spawn Points / Player:** referências já atribuídas.

Expande um recurso de `Waves`, ou abre seu `.tres`, para alterar `Penguins`, `Foxes`, `Red Pandas`, `Spawn Interval` e `Rest Time`. Para uma quinta onda, cria um `WaveDefinition`, salva em `Waves/Definitions` e adiciona ao array. Cada onda precisa ter ao menos um inimigo.

Move/adiciona `Marker3D` como filhos diretos de `SpawnPoints`. Eles precisam ficar próximos a um piso com colisão na camada 1 e espaço suficiente para a cápsula. O diretor busca chão até 5 m acima/10 m abaixo do marcador. Não coloca todos os pontos perto do jogador ou em áreas bloqueadas: a fila aguardará um ponto válido.

### Ajustar classes e modelos

Abre `Enemy/Profiles/penguin.tres`, `fox.tres` ou `red_panda.tres`. Edita vida, velocidade, dano, tempos de ataque, raio de AOE e resistências. Os nomes das propriedades estão em inglês no Inspector. Esses perfis prevalecem sobre os valores equivalentes do inimigo base durante `_ready()`.

Para mudar o modelo depois, edita a cena base ou a cena herdada da classe. Preserva os nós `Model`, `HealthComponent`, `HurtBox` e `AttackHitBox`. O modelo deve olhar para **+Z**. Se os nomes das animações mudarem, ajusta as constantes de animação e `attack_animation` em `enemy.gd`. Animações ausentes não quebram a lógica, mas não serão tocadas.

Se quiseres usar `.blend` diretamente no futuro, configura a instalação do Blender no editor e reativa **Project Settings → Filesystem → Import → Blender → Enabled**. O arquivo-fonte original continua no projeto.

### Controles desta entrega

| Entrada | Ação |
|---|---|
| WASD | Mover |
| Shift | Correr mais rápido (sprint) |
| Espaço | Pular / pulo aéreo disponível |
| Botão esquerdo | Combo terrestre ou aéreo; cliques durante o golpe alimentam o próximo |
| Q | Esquiva; depois de lançar um inimigo, tenta persegui-lo no ar |
| Botão direito | Guarda; apertar no instante certo faz perfect guard |
| F1 | Alternar invencibilidade para testes |
| F2 | Mostrar/esconder HUD |
| F5, com a janela do jogo em foco | Reiniciar a partida |
| Esc | Liberar cursor |

O launcher é o **terceiro golpe terrestre**. Após ele conectar, usa Q enquanto o alvo estiver no ar. Continua clicando para usar os golpes aéreos; o terceiro finaliza com slam. Esse comportamento reaproveita as habilidades existentes.

**Diferença do GDD:** RMB ainda é guarda, Q é dash, Shift é sprint; RMB pesado, Shift dash e R musou ficam para uma etapa de revisão do conjunto de golpes e do Input Map. Não foi remapeado silenciosamente um controle já funcional.

## 4. Validação e limites

- Importação do projeto na Godot 4.7 após regenerar `.godot`.
- Execução da cena principal por 600 frames em modo headless/fixed-fps 60, sem erros de runtime registrados.
- **37 verificações de regressão passaram**, incluindo quatro ondas, fila com pontos bloqueados, teto de inimigos, morte duplicada, remoção sem KO, vitória, perfis, AOE e interrupção, launcher no tanque, subida/hover, slam, fim aéreo, hitbox real sem dano duplicado, cancelamento, invulnerabilidade, parry e sobreposição de efeitos de tempo, morte e restauração do tempo.
- O cenário de teste remove intencionalmente um inimigo sem matá-lo: confirma **61 KOs para 62 inimigos gerados**. Em uma partida normal, derrotar todos rende 62 KOs.
- O teste está em `TesteRefatorado/Tests/combat_regression.gd`; resultado em `TesteRefatorado/Docs/VALIDACAO.txt`.

Para repetir, no terminal da raiz do projeto (usando o caminho do executável da Godot):

```text
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/combat_regression.gd
```

Os testes aceleram as ondas e causam dano programaticamente em parte dos cenários; há também verificações da hitbox real e da defesa. Eles não substituem jogar com mouse/teclado nem revisar enquadramento, animações, cores e sensação de impacto. Não houve avaliação visual interativa nem medição de FPS nesta entrega.

A importação limpa ainda relata dois materiais ausentes em **assets antigos**: `PLACEHOLDERS/Chars/Gato.obj` e `PLACEHOLDERS/Animationplaceholder/catboxmeme/source/Gato.obj` referenciam `Gato.mtl`, que não veio no ZIP. Eles não são usados pela cena de combate refatorada e não impediram os testes. Não inventei materiais para substituir esses arquivos.

A perseguição continua direta: funciona na arena aberta atual, mas não faz navegação ao redor de paredes ou labirintos. O spawner valida o local de nascimento, não a existência de uma rota navegável até o jogador. Não foi implementado pooling completo; a entrada gradual, o limite de vivos e a limpeza de cadáveres controlam o custo inicial.

## 5. Dicas para melhorar o jogo — próxima etapa

1. **Acertar o ritmo antes da arte final.** O primeiro golpe ainda tem 0,8 s de entrega e o terceiro tem 0,4 s de preparação. São valores relativamente longos para a intenção de combate rápido. Experimenta reduzir preparações e recuperações, alinhando as janelas de dano às animações para não criar hits sem contato.
2. **Criar ataque pesado com função própria.** Usa pesado para launcher/guard break e leve para sequência rápida. Assim o acesso ao ar fica deliberado, sem depender sempre do terceiro golpe. Depois decide se RMB será pesado e qual tecla assumirá a guarda.
3. **Separar pressão e quantidade de inimigos.** Muitas criaturas podem cercar o jogador, mas poucas deveriam iniciar ataques ao mesmo tempo. Um orçamento de atacantes reduz dano imprevisível e mantém a sensação de horda.
4. **Dar identidade legível às classes.** Além das cores provisórias, usa silhuetas, antecipações e sons diferentes. O anel do pinguim pode virar um arco/onda com material próprio; o panda pode ter uma postura defensiva claramente reconhecível.
5. **Refinar a câmera do combo aéreo.** Ajusta distância e enquadramento para manter jogador e alvo visíveis durante subida/slam. Evita correções bruscas de FOV a cada clique.
6. **Planejar limites do juggle.** Tempo máximo no ar, custo de dash aéreo ou resistência progressiva evitam combos infinitos. O objetivo deve ser preservar liberdade sem transformar o alvo em um boneco suspenso indefinidamente.
7. **Melhorar impacto com áudio e reação.** Sons de corte, variações de hit, faíscas e uma vibração curta de câmera ajudam a leitura; dosar hit-stop evita que acertar uma horda torne tudo lento demais.
8. **Introduzir o musou com uma regra simples.** Uma barra que cresce com acertos/defesas e um especial de limpeza de área já dão recompensa ao fluxo. O balanceamento vem antes de uma árvore grande de upgrades.
9. **Construir Cookie depois do núcleo estar estável.** Para o boss, usa padrões e janelas de vulnerabilidade, não apenas mais vida. Imunidade total a launcher apagaria a principal mecânica; uma quebra de postura pode liberar um combo aéreo curto.
10. **Medir antes de aumentar a horda.** Compara 16, 32 e 64 vivos no Profiler, separando scripts, física, esqueletos, sombras e efeitos. Se o gargalo passar a ser instanciação, considera pooling; se for renderização, LOD, redução de sombras e animações à distância.
11. **Adicionar navegação quando o mapa exigir.** Ao criar paredes e corredores, usa uma malha de navegação e valide também os pontos de spawn. Não basta mover os marcadores para uma sala desconectada.
12. **Criar uma pequena arena de treino.** Escolha de classe, vida infinita do alvo e exibição do estado do combo ajudam a ajustar alcance, altura, cancelamentos e timing antes de polir modelos.
