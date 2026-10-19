# Nyakuza — etapa 2: ritmo, pesado, coordenação e câmera

Esta versão continua a entrega de ondas/KOs/classes. O trabalho se concentra em `TesteRefatorado`. Modelos e animações continuam provisórios. **Não foram adicionados sons.**

## Log de mudanças

### 1. Ritmo dos golpes

Reduzidas preparação, entrega e recuperação das habilidades terrestres e aéreas. A velocidade do trecho animado agora é configurável por `Playback Speed`, sem depender de alterar os arquivos de animação. Os atrasos da hitbox e do rastro existente foram ajustados às novas durações.

| Golpe terrestre | Preparação anterior → nova | Entrega anterior → nova | Recuperação anterior → nova |
|---|---|---|---|
| Leve 1 | 0,10 → 0,055 s | 0,80 → 0,24 s | 0,20 → 0,10 s |
| Leve 2 | 0,30 → 0,07 s | 0,50 → 0,27 s | 0,20 → 0,11 s |
| Leve 3 | 0,40 → 0,09 s | 0,50 → 0,30 s | 0,50 → 0,14 s |

A soma nominal dos três leves passou de **3,50 para 1,375 s**, sem considerar hit-stop e cancelamentos. Isso é uma mudança de temporização, não uma medição de velocidade percebida por um jogador.

- Buffer de entrada de 0,28 s, com apenas um próximo comando. O último clique leve/pesado substitui o anterior.
- O comando expira: um clique antigo não dispara um ataque muito depois.
- O próximo golpe pode começar na recuperação após um mínimo de 0,035 s. Não cancela a entrega de dano para encadear outro golpe.
- Guarda e dash continuam podendo interromper o golpe.
- Cliques durante a subida aérea aguardam o hover, respeitando a mesma validade do buffer.
- Hit-stop dos leves foi reduzido para evitar que muitos acertos deixem toda a sequência excessivamente lenta.

Os timings são um ponto inicial para os placeholders atuais. O alinhamento visual exato deve ser ajustado quando substituíres as animações.

### 2. Ataque pesado com função própria

- **RMB no chão: HeavyLauncher.** Dano 22 e impulso vertical 10 m/s.
- **RMB durante o combo aéreo: HeavySlam.** Dano 22 e finalização descendente, reaproveitando impacto e onda de choque existentes.
- O pesado usa 0,13 s de preparação, 0,30 s de entrega e 0,18 s de recuperação. Intervalo mínimo entre inícios: 0,55 s.
- O terceiro leve terrestre agora empurra horizontalmente; o launcher deixou de depender de terminar a sequência de leves.
- O terceiro leve aéreo continua podendo finalizar com slam. O pesado oferece acesso direto ao finisher.
- O pesado reinicia o índice do combo leve; a próxima sequência começa no primeiro leve.
- Hurtboxes, detecção de um acerto por swing e cancelamento de dano atrasado continuam compartilhados.
- **A guarda passou do RMB para F**, evitando que pesado e guarda disparem juntos. O Input Map já foi atualizado no projeto.

A função escolhida para o pesado é launcher/finisher. Não foi inventado um sistema de escudos inimigos apenas para oferecer quebra de defesa.

### 3. Limite de ataques inimigos

Novo nó `AttackCoordinator` em `CombatScene`:

- `Max Attackers = 2`: no máximo dois inimigos entre preparação, impacto e recuperação.
- `Max Area Attackers = 1`: apenas um pinguim executando AOE nesse intervalo.
- `Start Spacing = 0.18`: evita dois inimigos começarem seus ataques no mesmo instante.
- A fila dá prioridade aos candidatos elegíveis que já estavam esperando. Um candidato fora de alcance, morto ou interrompido sai da fila.
- A vaga é liberada por stagger, launcher, parry, morte, remoção e término da recuperação.
- Se o jogador entra no combo aéreo durante a preparação inimiga, a preparação é cancelada e libera a vaga.
- O limite não reduz a quantidade de criaturas na arena: os outros continuam presentes, perseguindo ou aguardando alcance/vaga.
- O coordenador expõe `Nyakuza/Attacking` em **Debugger → Monitors**.

Cenas antigas sem `AttackCoordinator` mantêm o comportamento anterior. A cena principal já tem o nó conectado por grupo; não é preciso ligar sinais manualmente.

### 4. Câmera durante subida e slam

O `CamRoot` agora faz enquadramento aéreo com suavização:

- Foco interpolado entre jogador e alvo, com peso padrão 0,45 e deslocamento máximo de 3 m.
- Distância-base de 3 m; distância aérea de referência 4,8 m, aumentando no slam para 6,5 m, mais um ajuste pelo afastamento do foco; teto configurável de 10 m.
- Inclinação assistida de referência -12° no ar e -28° no slam, combinada com a inclinação escolhida pelo jogador.
- O mouse continua controlando a câmera. Ao mover o mouse, a assistência de inclinação cede por 0,8 s.
- FOV aéreo estável de 76°, evitando zoom a cada golpe. O dash ainda pode usar sua variação própria.
- A câmera acompanha brevemente a descida por 0,45 s ao terminar o combo e retorna suavemente à base.
- Alvos removidos/mortos são tratados sem acessar referências inválidas; morte do jogador limpa o enquadramento aéreo.
- `SpringArm3D` considera somente a camada do mundo, excluindo o jogador: corpos da horda não encurtam o braço da câmera.

Os testes verificaram estados, distância, limites e retorno. Não foi feita uma avaliação visual interativa do enquadramento no teu monitor; isso permanece parte do teste jogável.

### 5. Medição antes de aumentar a horda ou usar pooling

Criada `TesteRefatorado/Benchmark/BenchmarkScene.tscn`:

- Cargas de 16, 32 e 64 inimigos, mesclando as três classes.
- Jogador invencível, ondas desligadas e separação espacial ativa.
- 180 frames de aquecimento e 600 de captura.
- Seed fixa 1977; o cenário de referência é jogador parado, IA ativa, sem ataques do jogador.
- Exporta JSON com amostras e resumos de processamento, física, memória, nós, draw calls, atacantes e custo de criação de cada inimigo.
- Monitores personalizados de atacantes, inimigos vivos e última instanciação.
- O roteiro de teste de desempenho e os resultados estão em `TesteRefatorado/Docs/BENCHMARK.md` e `Benchmark/Results`.

**Decisão desta etapa:** manter 16 vivos na partida normal e não adicionar pooling completo. A comparação de CPU/física e os custos de criação foram medidos antes dessa decisão. A coleta é headless: não mede o custo real de GPU, sombras, materiais, desenho dos esqueletos ou efeitos na tua máquina. Logo, não autoriza prometer 60 FPS nem subir o limite automaticamente.

## O que fazer na engine

### Abrir a versão completa

1. Extrai `Nyakuza.zip` em uma nova pasta, mantendo tua cópia anterior.
2. Importa `Nyakuza/project.godot` na **Godot 4.7** e aguarda a reimportação.
3. Abre `res://TesteRefatorado/Scene/CombatScene.tscn`.
4. Usa F6 para testar a cena ou F5 no editor para iniciar o projeto.

A cena já contém o coordenador, os dois nós de pesado, as referências e os novos controles. **Não é necessário montar os nós manualmente.**

### Aplicar o patch

`Nyakuza_patch.zip` é incremental **sobre a primeira entrega modificada** (a versão com quatro ondas e 62 inimigos). Não é um projeto independente e não serve sozinho sobre o primeiro upload original. Extraia sobre uma cópia daquela entrega, alinhando a pasta `Nyakuza` com a raiz do projeto e substituindo os arquivos listados em `Docs/ARQUIVOS_ALTERADOS_ETAPA2.txt`.

Se já fizeste outras alterações locais, compara os scripts/cena antes de sobrescrever. O projeto completo é a opção mais simples para evitar mistura de versões.

### Controles atualizados

| Entrada | Função |
|---|---|
| LMB | Ataque leve / sequência leve |
| **RMB** | **Launcher no chão; slam no combo aéreo** |
| **F** | **Guarda / perfect guard** |
| Q | Dash; próximo de um alvo lançado, perseguição aérea |
| WASD | Movimento |
| Shift | Sprint |
| Espaço | Pulo / pulo aéreo |
| F1 / F2 | Invencibilidade / mostrar-esconder HUD |
| F5 dentro do jogo | Reiniciar a cena |
| Esc | Liberar cursor |

Fluxo para conferir: **RMB → acertar o launcher → Q → LMB para hits aéreos → RMB para slam**. Também testa LMB → LMB → RMB, guarda com F durante a preparação do pesado e dash para cancelar.

R continua livre; o especial musou não faz parte desta etapa. O controle de videogame tem pesado em Y e guarda em LB, mas o restante do projeto continua orientado a mouse/teclado; não é anunciado suporte completo a controle.

### Onde ajustar

- **Ritmo:** `Player → MeshRoot → SpikePrototipo → target_character → Skeleton3D → katana → SkillsContainer`. Abre `ActiveSkill_1/2/3`, `AirSkill_1/2/3`, `HeavyLauncher` e `HeavySlam`. Ajusta `Windup Duration`, `Delivery Duration`, `Recovery Duration`, `Animation Start Offset`, `Playback Speed` e `Hit Delay`.
- **Buffer e intervalo do pesado:** nó `Player/ActiveSkillController`.
- **Pressão da horda:** nó raiz `AttackCoordinator`. Aumentar `Max Attackers` afeta dificuldade, não quantos inimigos existem.
- **Enquadramento:** nó `Player/CamRoot`, seção `Aerial Framing`. Desmarca `Aerial Framing` para comparar com o enquadramento sem assistência.
- **Ondas e quantidade viva:** continuam no `WaveDirector`, como na entrega anterior. Não aumentei `Max Alive` automaticamente.

### Repetir o benchmark no Profiler

1. Abre `res://TesteRefatorado/Benchmark/BenchmarkScene.tscn` e executa com F6.
2. Usa **1, 2 ou 3** para selecionar 16, 32 ou 64 inimigos. Cada seleção recria o cenário e inicia a captura. **F7** repete a captura da carga atual.
3. No editor, abre **Debugger → Profiler** e pressiona **Start**. Observa o custo dos scripts e da física durante a parte estável, após a criação dos inimigos.
4. Em **Monitors**, acompanha `Nyakuza/Attacking`, `Nyakuza/Alive`, `Nyakuza/Spawn_ms`, memória e chamadas de desenho. No **Visual Profiler**, observa CPU/GPU e sombras com renderização ligada.
5. O JSON é gravado em `user://nyakuza_benchmark.json`. Usa **Project → Open User Data Folder** para encontrá-lo. Copia/renomeia após cada rodada, pois a próxima sobrescreve o mesmo arquivo.
6. Faz três rodadas por carga, na mesma resolução, renderer e configuração gráfica, mantendo o jogador parado. Depois faz um segundo conjunto atacando e usando combos aéreos — esse conjunto mede outro cenário, com VFX e dano.

Os monitores internos podem atualizar em intervalos próximos de 1 s. Os percentis do JSON descrevem as amostras desses monitores, não uma medição independente do custo de cada frame. Para analisar picos individuais, usa o histórico do Profiler. Não some diretamente `Process` e `Physics` como se fossem necessariamente custos independentes.

Referências da API consultadas: [Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html), [Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html), [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html).

## Validação

- Godot 4.7 stable, Linux, headless.
- **37 verificações anteriores aprovadas**, preservando ondas, KOs, classes e cancelamentos.
- **33 verificações novas aprovadas**: Input Map, função do pesado, launcher real, combo aéreo, slam, câmera, buffer, cancelamento, duas vagas, fila, limite de AOE, intervalo de início, liberação por parry/morte/remoção e limpeza dos monitores.
- Logs em `Docs/VALIDACAO_ETAPA2.txt`.
- Nenhum som novo, modelo substituído ou sistema musou/boss adicionado.

Para repetir os testes, a partir da raiz do projeto:

```text
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/combat_regression.gd
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/refinement_regression.gd
```

`--fixed-fps` é adequado para as verificações funcionais, mas não para esta coleta de desempenho. O benchmark usa execução em tempo real, com limite de 60 FPS e profiling habilitado.

Continuam os dois avisos de materiais `Gato.mtl` ausentes nos OBJ antigos que não são usados na cena principal; não impediu a importação dos recursos de combate. A importação direta de Blender continua desligada conforme a primeira entrega.

## Dicas para a próxima etapa

1. **Jogar e calibrar as novas janelas.** Verifica se o pesado parece pesado o suficiente e se os leves não perdem legibilidade. Ajusta animação e hitbox juntas.
2. **Dar escolha ao fim do ar.** Um finisher horizontal ou um dash aéreo lateral pode criar decisões além de sempre terminar em slam, sem exigir muitas habilidades novas.
3. **Aprimorar posicionamento dos inimigos em espera.** Com vagas de ataque funcionando, os demais podem circular, flanquear ou manter distância, em vez de esperar na mesma linha.
4. **Planejar resistência ao juggle.** Para elites e Cookie, uma barra de postura pode liberar uma janela aérea; evita imunidade total que anule o diferencial do combate.
5. **Definir o musou em uma única habilidade.** Barra que cresce com acertos/parries, uso em R e uma função clara de controle de multidão são suficientes para o próximo protótipo.
6. **Testar a câmera em situações extremas.** Alvo junto de parede, mudança brusca de direção, morte no ar e vários inimigos lançados. Mantém a assistência opcional.
7. **Separar custo de renderização e instanciação.** Se aparecer gargalo em sombras/animações, pooling não resolverá esse problema. Só introduz pooling quando os picos de criação/destruição forem demonstrados.
8. **Criar navegação quando houver obstáculos reais.** A perseguição ainda é direta e apropriada à arena aberta; um mapa com paredes precisa de rotas navegáveis e validação dos pontos de nascimento.

O histórico da etapa anterior foi preservado em `Docs/HISTORICO_ETAPA1.md`. Seus controles antigos são históricos; os controles válidos desta entrega são os da tabela acima.
