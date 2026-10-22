# Nyakuza — etapa 3: flanqueamento, postura, musou e toon

Esta entrega continua a etapa de combate rápido, pesado e câmera aérea. As alterações de jogo estão em `TesteRefatorado`; o Input Map foi atualizado em `project.godot`. Não foi criada alternativa ao slam. Não foram adicionados sons nem substituídos os modelos provisórios.

## Log de alterações

### Inimigos circulam e flanqueiam

- A até 7 m, a perseguição procura um ponto lateral/traseiro relativo à direção do personagem. Cada inimigo recebe um lado e um ângulo de aproximação.
- Dentro do alcance, quem aguarda vaga ou cooldown circula em vez de ficar parado. Um ajuste radial mantém o inimigo próximo do alcance de ataque, e a separação existente ajuda a evitar sobreposição.
- O movimento de espera usa 55% da velocidade da classe. O corpo continua virado para o jogador; a animação de corrida ainda é placeholder, sem animação específica de strafe.
- Uma sondagem curta de colisão a cada 0,2 s inverte o sentido de circulação diante de um obstáculo.
- Continuam as duas vagas de ataque, o limite de um ataque em área e o intervalo entre inícios. A fila do `AttackCoordinator` continua decidindo quem pode atacar.

É um comportamento local para a arena atual. Não é navegação completa: obstáculos extensos, corredores e esquinas ainda exigem NavigationRegion/NavigationAgent e um mapa navegável.

### Postura quebrável por ataques fortes

O panda-vermelho é a primeira classe com postura. Raposas e pinguins permanecem sem essa armadura.

| Parâmetro | Valor inicial |
|---|---:|
| Postura do panda-vermelho | 60 |
| Dano de postura de cada pesado | 35 |
| Janela após a quebra | 6 s |
| Atraso para regenerar postura parcialmente danificada | 3 s sem dano de postura |
| Regeneração | 10 pontos/s |

- Postura intacta bloqueia stagger, empurrão e lançamento por golpes comuns, mas **não reduz o dano de vida**. Não é um segundo HP.
- Leves tiram vida, mas não postura. Os dois pesados estão marcados com `Is Heavy = true` e `Posture Damage = 35`.
- Dois pesados próximos quebram a postura. O mesmo golpe que zera a barra já aplica seu launcher, sem exigir um terceiro ataque.
- A barra amarela acima do inimigo mostra a postura. Ao quebrar, aparece “POSTURA QUEBRADA” e a barra vazia fica azul.
- A postura volta inteira depois da janela, desde que o inimigo esteja no chão e fora do estado aéreo. Nunca volta no meio do slam.
- Perfect guard ainda interrompe inimigos com postura intacta, mas não quebra essa barra sozinho.
- A musou causa dano de vida em elites, mas não dano de postura. Assim, o pesado mantém essa função.

### Musou: esfera de cortes persistente

**R**, com a barra cheia e o jogador no chão, cria uma esfera fixa à frente do personagem. Ela continua cortando enquanto tu podes te mover e atacar normalmente.

| Parâmetro | Valor inicial |
|---|---:|
| Carga máxima / inicial | 100 / 0 |
| Carga por vítima atingida por leve | 6 |
| Carga por vítima atingida por pesado | 8 |
| Carga por perfect guard | 12 |
| Distância de criação à frente | 3 m |
| Raio | 3,2 m |
| Duração | 4 s de tempo de jogo |
| Intervalo entre pulsos | 0,25 s |
| Dano por pulso | 8 |

A função escolhida é **controle e dano numa área persistente**. Não é uma animação cinematográfica nem uma reprodução exata das habilidades de Vergil/Ayaka.

- O efeito tem uma superfície translúcida com cortes animados e três lâminas circulares inclinadas. É procedural e não depende de texturas externas novas.
- A esfera fica onde foi criada; não segue o jogador e não busca inimigos automaticamente.
- A posição é ajustada diante de uma parede e precisa encontrar chão. O ponto de criação usa a frente do corpo, não um alvo marcado pelo mouse.
- Cada pulso verifica distância até o centro do inimigo e linha de visão na camada do mundo. Não atravessa paredes para causar dano.
- Há stagger curto em inimigos comuns no chão. Em alvos aéreos, os pulsos não renovam a suspensão nem alteram a queda do slam.
- Com os valores padrão, um alvo presente em todos os 16 pulsos pode receber 128 de dano. Entrar tarde ou sair do raio reduz esse total.
- Não há dano no jogador. Matar com a esfera passa pelo fluxo normal de morte e conta KO uma única vez.
- Não há invulnerabilidade concedida pela ultimate. A ativação cancela guarda, ataque e deslocamento de golpe; depois devolve o controle.
- Não se pode ativar no ar. Tentativas inválidas não gastam carga e mostram um aviso no HUD.
- Só existe uma esfera ativa por jogador. Enquanto ela está ativa, a carga não sobe, mesmo com ataques da espada. Seus próprios pulsos nunca geram carga.
- Morte do jogador, reinício ou encerramento da cena removem o campo. Reiniciar também reinicia a carga.
- A barra e o aviso “R — MUSOU PRONTA” foram adicionados ao HUD. Os hits do campo entram no contador de combo.

Para evitar poluir a tela, só um a cada quatro pulsos produz número flutuante. Esse número mostra o dano daquele pulso, não a soma dos quatro. A vida continua sendo reduzida em todos eles.

### Toon shader

Criei um material autoral com um ponto intermediário entre as referências: contraste e massas escuras fortes, bordas gráficas, sombras violeta, cores saturadas e transições estreitas com rim light discreto. O resultado depende também da iluminação, das texturas e das normais do modelo; o shader sozinho não reproduz toda a direção de arte desses jogos.

- `nyakuza_toon.gdshader`: três faixas de iluminação, cores de sombra/meio-tom, suavidade, saturação, rim e hachura opcional nas sombras.
- `ink_outline.gdshader`: contorno por casca invertida em uma segunda passagem. Espessura em metros, não em pixels.
- `toon_balanced.tres`: preset-base usado pelos inimigos, com cor de cada classe.
- `player_toon.tres`: mesmo shader, preservando a textura do jogador e com hachura mais discreta.
- `katana_toon.tres`: preserva a textura da espada, com rim um pouco mais forte e sem hachura.
- `toon_noir.tres` e `toon_soft.tres`: opções mais contrastada e mais suave para comparação.
- `ToonPreview.tscn`: bancada com os três presets sob a mesma luz.

O material antigo do corpo do jogador era aplicado como overlay completo. Agora o toon usa `Material Override`, evitando desenhar uma segunda superfície inteira só para sombrear. O contorno ainda adiciona sua própria passagem. O flash de dano/aviso vermelho dos inimigos continua como overlay independente.

O shader foi aplicado ao jogador, à katana e aos inimigos. Os materiais da arena foram preservados. Os shaders antigos continuam disponíveis para cenas legadas.

## Como aplicar na Godot

### Projeto completo

1. Extraia `Nyakuza.zip` em uma pasta nova.
2. Importe `Nyakuza/project.godot` na Godot 4.7 e espere a importação terminar.
3. Abra `res://TesteRefatorado/Scene/CombatScene.tscn` e pressione F6; F5 inicia o projeto.
4. Não é necessário criar nós nem conectar sinais manualmente: `Player/MusouController`, Input Map, materiais e referências já estão prontos.

### Patch incremental

`Nyakuza_patch.zip` deve ser aplicado **sobre a etapa 2 entregue anteriormente**, a versão com pesado em RMB, guarda em F e câmera aérea. Não é um projeto independente nem um patch direto sobre o upload original.

Feche a Godot, faça uma cópia da tua versão e extraia o patch alinhando a pasta `Nyakuza` com a pasta do projeto. Substitua os arquivos indicados em `TesteRefatorado/Docs/ARQUIVOS_ALTERADOS_ETAPA3.txt`. Se já editaste esses arquivos localmente, compara antes de sobrescrever. Para evitar mistura de versões, prefira o ZIP completo.

### Controles

| Tecla | Ação |
|---|---|
| LMB | Leve / combo |
| RMB | Pesado: launcher no chão / slam no combo aéreo |
| F | Guarda / perfect guard |
| Q | Dash / perseguição de alvo lançado |
| R | Musou com carga cheia, no chão |
| WASD / Shift / Espaço | Movimento / sprint / salto |
| F1 / F2 | Invencibilidade de teste / esconder HUD |
| F5 dentro do jogo | Reiniciar |
| Esc | Liberar cursor |

A ação `musou` está mapeada no teclado. Não foi implementado um esquema completo de controle de videogame nesta etapa.

### Roteiro rápido para conferir

1. Contra uma raposa: RMB deve lançar imediatamente; Q segue para o combo aéreo.
2. Contra um panda-vermelho: leves tiram vida, mas não a barra amarela. Acerte dois RMB antes de ela regenerar; o segundo deve quebrar e lançar.
3. Rodeie uma horda sem atacar e observe os inimigos que aguardam vaga se moverem lateralmente. Só dois devem entrar em preparação/ataque/recuperação ao mesmo tempo.
4. Carregue a barra com acertos e perfect guards, fique no chão e pressione R. Afaste-se: a esfera deve ficar no lugar.
5. Para testar R imediatamente, selecione `Player/MusouController` e coloque **Initial Charge = 100** no Inspector. Volte para 0 depois; F1 concede invencibilidade, não carga.
6. Abra `res://TesteRefatorado/Visuals/ToonPreview.tscn` e use F6 para comparar os materiais.

## Onde ajustar e como o código funciona

### Responsabilidades dos arquivos

| Arquivo dentro de TesteRefatorado | Responsabilidade |
|---|---|
| `Enemy/enemy.gd` | Estados, flanqueamento, postura e reação ao dano |
| `Enemy/enemy_profile.gd` e `Enemy/Profiles/*.tres` | Valores iniciais de cada classe |
| `Combat/attack_coordinator.gd` | Vagas e fila de ataques; não move os inimigos |
| `Skill/active_skill.gd` | Dados editáveis dos golpes, incluindo dano de postura |
| `Combat/hit_data.gd` | Pacote de dados de um golpe |
| `Combat/hit_box.gd` | Converte habilidade em HitData e evita hit duplicado por swing |
| `Musou/musou_controller.gd` | Entrada R, carga, validação e criação da esfera |
| `Musou/musou_sphere.gd` | Pulsos, alcance, paredes, duração e efeito visual |
| `Combat/combat_hud.gd` | Exibição da carga e mensagens |
| `Visuals/*.gdshader` e `Visuals/*.tres` | Código de sombreamento e seus presets |

**Como dar postura a outra classe?** Abra o `.tres` em `Enemy/Profiles` e altere `Posture Max` para um valor maior que zero. Zero desliga a mecânica. Não altere o Resource durante a partida: ele é compartilhado. `_apply_profile()` copia os valores para cada inimigo, enquanto `posture` guarda o estado individual.

**Como mudar quantos pesados quebram?** Ajuste `Posture Max` no perfil ou `Posture Damage` nos nós `HeavyLauncher` e `HeavySlam`. Eles ficam em `Player/MeshRoot/SpikePrototipo/target_character/Skeleton3D/katana/SkillsContainer`. Sem regeneração entre acertos, a quantidade é o teto de `Posture Max / Posture Damage`; 60/35 exige dois. O golpe precisa ter `Is Heavy` ligado: aumentar apenas `Damage` não faz dele um ataque forte para a postura.

**Por que leves não interrompem um elite?** É a armadura de postura funcionando. O dano de vida já foi aplicado antes da checagem. A quebra é calculada antes da reação, permitindo que o próprio pesado que quebra lance. Parry tem uma rota própria e continua interrompendo.

**A postura impede combo infinito depois de quebrada?** Não completamente. Ela controla a entrada no juggle e não volta no meio dele. Um limite absoluto de duração aérea ou rendimentos decrescentes ainda seria uma mecânica separada; não interrompi um combo ativo arbitrariamente.

**Onde ajustar flanqueamento?** Em `Enemy.tscn`, selecione o nó raiz e use `Crowd Positioning`: `Flank Enabled`, `Orbit Speed Scale` e `Flank Distance`. O script mistura direção tangencial, correção radial e separação. `_start_attack()` ainda precisa obter vaga do coordenador. Não remova esse pedido para “destravar” um inimigo, pois ele é o limite de pressão da horda.

**Onde ajustar a ultimate?** No nó `Player/MusouController`, use as seções `Charge` e `Cutting Sphere`. `Damage Per Tick` é por pulso: reduzir `Tick Interval` aumenta o número de pulsos e, portanto, o dano total. O tempo usa o delta do jogo; hit-stop/slow motion também desaceleram sua duração. A esfera é irmã do jogador na árvore, por isso não acompanha sua transformação.

**Por que minha musou não ativa ou não carrega?** O HUD informa carga insuficiente, uso no ar, campo já ativo ou ausência de chão à frente. Ela exige 100 de carga por padrão. A carga vem por vítima atingida, então um golpe que pega vários inimigos carrega mais. Não há ganho passivo, por bloqueio comum, onda de choque de slam ou pulso da esfera. Durante um campo ativo, toda recarga fica suspensa.

**Por que a esfera não usa uma hitbox continuamente ligada?** A mecânica usa pulsos a 4 Hz, uma consulta ao grupo `enemies` por pulso e um raycast apenas para cada candidato dentro do raio. Isso evita dano dependente do número de frames e mantém a filtragem de paredes. A seleção usa o centro aproximado do inimigo (posição + 1 m), não interseção exata com toda a malha. Ajusta isso para bosses muito grandes.

**Como trocar o visual da esfera?** Edite `cut_color` no shader para a cor padrão, ou os materiais em `_build_visuals()`. O dano está separado em `_pulse()`: podes substituir o visual por partículas/animação sem alterar os KOs. A casca translúcida não colide; paredes limitam o dano, mas podem atravessar visualmente parte do efeito.

### Ajustar o toon no Inspector

Abra `Visuals/player_toon.tres`, `toon_balanced.tres` ou outro preset. Expanda **Shader Parameters**.

| Parâmetro | Efeito |
|---|---|
| `base_color` / `albedo_texture` | Cor base e textura UV |
| `shadow_color` / `mid_color` | Cor das faixas de sombra e meio-tom |
| `shadow_threshold` / `light_threshold` | Onde cada faixa começa; mantenha o primeiro menor que o segundo |
| `edge_softness` | Menor = corte mais duro; maior = transição suave |
| `ambient_floor` | Piso de claridade nas zonas sem luz direta |
| `saturation` | Intensidade das cores |
| `rim_strength` / `rim_power` | Intensidade e concentração da borda iluminada |
| `hatch_strength` / `hatch_scale` | Força e frequência da trama nas sombras; zero desliga |
| `Next Pass → Shader Parameters → width` | Espessura do contorno |

Para um resultado mais noir/gráfico, comece pelo preset `toon_noir`. Para algo mais suave, use `toon_soft`. O padrão do jogo é `toon_balanced`, com adaptações para textura do jogador e espada. São presets autorais, não shaders extraídos dos jogos de referência.

**Como aplicar ao gato/modelo definitivo?** Selecione o `MeshInstance3D` real do modelo e coloque um material duplicado em **Geometry → Material Override**, ou aplique por superfície se houver materiais diferentes para pelo/terno/olhos. Defina a textura em `albedo_texture`. Ao usar um único Override, ele substitui todos os materiais da malha: para UVs/texturas separadas, prefira materiais por superfície. Não aplique no Skeleton3D nem no AnimationPlayer. Confira escala, normais suavizadas e UVs antes de calibrar contorno/hachura.

**Por que o contorno pode apresentar emendas?** A casca extruda as normais da malha; normais duras, vértices separados e superfícies abertas podem revelar falhas. Reduza `width` ou desative `Next Pass` nesse material. A largura é em metros, então sua espessura aparente varia com a distância. Cabelos/cartões transparentes precisam de material próprio; este toon é opaco.

**Preciso refazer a iluminação?** O material recebe luz direta e sombras; uma luz principal clara facilita ler as faixas. Muitas luzes fortes somam contribuições e podem lavar o contraste. A arena continua com sua iluminação anterior. Calibre primeiro na bancada `ToonPreview`, depois na cena do jogo. Para as sombras do rosto do gato definitivo, um tratamento específico de normais/máscara poderá ser necessário.

**Impacto de desempenho?** O contorno acrescenta uma passagem por malha e a esfera tem transparência. Não prometa ganho só por usar toon. O campo reutiliza quatro malhas enquanto está ativo e evita criar um efeito novo a cada hit, mas ainda há custo de desenho e consultas de dano. O limite normal de 16 vivos foi mantido. Os benchmarks em `Docs/BENCHMARK.md` são históricos da etapa 2, anteriores a esses efeitos.

## Validação e limites

- Godot 4.7 stable, Linux, execução headless.
- 37 verificações de combate/ondas, 33 de refinamento e 47 desta etapa: **117 verificações aprovadas**.
- Os testes antigos de combo aéreo agora usam um alvo sem armadura ou com postura já quebrada; os novos verificam a quebra real do elite pela hitbox do pesado.
- Validação sintática dos três shaders por leitura dos uniformes: 14 no toon, 2 no contorno e 2 na esfera.
- Cena de comparação carregada em modo headless. Não houve validação visual nem medição de GPU: a aparência renderizada, transparência e contorno precisam ser conferidos na tua máquina.
- Logs em `Docs/VALIDACAO_ETAPA3.txt`.
- Permanecem avisos de `Gato.mtl` ausente em OBJ antigos, fora da cena principal. Não impedem o combate; não inventei materiais para esses arquivos legados.

Comandos para repetir a partir da raiz do projeto (substitua `godot` pelo caminho do executável):

```text
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/combat_regression.gd
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/refinement_regression.gd
godot --headless --path . --fixed-fps 60 --script res://TesteRefatorado/Tests/stage3_regression.gd
godot --headless --path . --script res://TesteRefatorado/Tests/shader_validation.gd
```

Referência técnica do shader: [Spatial shaders — documentação oficial Godot](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). Os históricos das entregas anteriores estão em `Docs/HISTORICO_ETAPA1.md` e `Docs/HISTORICO_ETAPA2.md`.

## Dicas para a próxima etapa

1. Calibrar em jogo o tempo para encher a musou; ganhar carga por vítima favorece hordas e pode encher rápido em grupos densos.
2. Testar se dois pesados e 6 s de vulnerabilidade deixam o panda interessante sem tornar a postura uma obrigação repetitiva.
3. Criar animações de strafe e um aviso visual próprio de postura intacta/quebrada, preservando a distinção do aviso vermelho de ataque.
4. Conferir a esfera perto da câmera e de paredes; reduzir opacidade e quantidade de linhas se esconder os inimigos.
5. Definir uma paleta do personagem e testar o toon no gato definitivo antes de aplicar o mesmo material em toda a arena.
6. Medir no Visual Profiler o contorno e a transparência com horda + musou. Otimizar o efeito que aparecer como gargalo antes de aumentar o número de inimigos.
7. Adicionar navegação completa quando a arena ganhar obstáculos que exijam contorno de rotas.
