# Benchmark — etapa 2

Medições locais em Godot 4.7 stable, Linux x86_64, CPU AMD EPYC 9V74 em ambiente compartilhado. Sem renderização (`headless`). Três execuções por carga, com profiling habilitado e limite de 60 FPS, sem `--fixed-fps`.

Cada execução usa seed 1977, jogador parado e invencível, três classes de inimigos com IA ativa, sem ataques do jogador. Cria um inimigo por frame de física; depois aguarda 180 frames de aquecimento e coleta 600 amostras. O benchmark não altera a quantidade máxima de inimigos da partida normal.

Valores em milissegundos: **mediana das médias das três execuções (menor–maior média)**. Processamento e física não devem ser somados como custos necessariamente independentes. Spawn inclui instanciação e inserção na árvore, medido por inimigo.

| Inimigos | Processamento ms | Física ms | Spawn por inimigo ms | Máximo de atacantes |
|---|---|---|---|---|
| 16 | 2.910 (2.412–3.302) | 4.605 (3.298–4.663) | 0.636 (0.633–0.674) | 2 |
| 32 | 2.756 (2.445–2.788) | 4.435 (3.995–4.765) | 1.025 (0.934–1.028) | 2 |
| 64 | 5.882 (4.460–14.195) | 13.123 (8.643–13.333) | 1.040 (0.848–1.267) | 2 |

## Interpretação e decisão

A carga de 64 teve custo e variabilidade maiores. As execuções de 16 e 32 se sobrepõem; não seria correto concluir que 32 custa menos com base em uma rodada. O ambiente compartilhado introduz ruído, e não foi isolada a contribuição exata de cada script.

O custo de criação observado não demonstra que pooling seja a prioridade. Na partida normal as criações já são espaçadas; o teste não mede todo o ciclo de destruição e reciclagem. Mantido o limite normal de 16 vivos e adiado pooling até haver evidência no hardware alvo.

Os monitores de Performance atualizam em intervalos próximos de 1 s: os percentis salvos representam amostras repetidas dos monitores, não percentis independentes de cada frame. Draw calls igual a zero é efeito do modo headless, não indicação de custo gráfico nulo. Não foram medidos GPU, sombras e renderização real; não há promessa de 60 FPS.

## Reproduzir

Na Godot, abra `res://TesteRefatorado/Benchmark/BenchmarkScene.tscn`, execute com F6 e use 1/2/3 para 16/32/64 inimigos. F7 repete a captura atual. Abra Debugger → Profiler → Start e Monitors. Com renderização ligada, consulte também Visual Profiler. O resultado é sobrescrito em `user://nyakuza_benchmark.json`; copie após cada rodada.

Para repetir a coleta headless a partir da raiz do projeto:

```text
godot --headless --profiling --max-fps 60 --path . res://TesteRefatorado/Benchmark/BenchmarkScene.tscn -- --auto --count=16 --result=/caminho/absoluto/bench16.json
```

Troque count para 32 e 64 e faça três rodadas. Para medir o jogo completo, repita no hardware alvo com renderização ligada e depois em um cenário separado com ataques, VFX e combos aéreos. Compare picos por função no Profiler antes de escolher uma otimização.

Os nove JSONs originais estão em `TesteRefatorado/Benchmark/Results`. `realtime` indica a primeira rodada; `run2` e `run3`, as repetições. Execuções preliminares aceleradas foram descartadas por não darem tempo suficiente para atualizar os monitores.
