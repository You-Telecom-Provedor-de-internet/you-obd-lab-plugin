# YOU OBD Lab Complete Guide

## 1. O que e o YOU OBD Lab

`YOU OBD Lab` e um plugin local do Codex criado para transformar o ecossistema YOU em um laboratorio de validacao assistido por IA.

Ele conecta, num unico fluxo, estes mundos:

- `YouSimuladorOBD`
- `YouAutoCarvAPP2`
- `firmware/YouAutoTester`
- celular Android real via `ADB`
- `OBD real`
- API e oracle do simulador
- evidencia de bancada
- LLMs locais via `Ollama`

O objetivo do plugin nao e ser so um conjunto de scripts. O objetivo e dar ao Codex uma forma consistente de:

- entender ownership
- congelar contratos
- validar comportamento
- revisar risco
- coletar evidencias
- resumir telemetria com apoio de modelos locais

## 2. Problema que o plugin resolve

Sem o plugin, o fluxo costuma ficar espalhado entre:

- scripts soltos
- memoria do operador
- passos nao documentados
- logs sem timeline
- divergencia entre simulador, app e bancada

Com o plugin, o fluxo passa a ser:

- orientado por skills
- reproduzivel por fixture e por script
- apoiado por agentes especializados
- auditavel por evidencias

## 3. Sistemas em escopo

### Repositorios

- `C:\www\YouSimuladorOBD`
- `C:\www\YouAutoCarvAPP2`
- `C:\www\you-obd-lab-plugin`

### Superficies fisicas e operacionais

- celular Android real
- `ADB`
- Wi-Fi ou USB para o device
- adaptadores `ELM327` e `OBDLink`
- hardware de bancada
- API do simulador
- WebSocket, logcat, screenshot e logs locais

## 4. Modelo de IA do plugin

O plugin segue um modelo hibrido.

### Modelo principal

- `gpt-5.4`

Ele fica responsavel por:

- orquestracao
- leitura final de risco
- revisao final
- interpretacao final de contratos
- decisao final de edicao ou merge

### Modelos locais via Ollama

Perfis suportados:

| Perfil | Modelo | Papel |
| --- | --- | --- |
| `rapido` | `qwen2.5-coder:7b` | triagem curta |
| `analitico` | `deepseek-r1:8b` | comparacao e primeira leitura |
| `pesado` | `gpt-oss:20b` | condensacao maior e leitura de escopo amplo |

Esses modelos entram como apoio para:

- resumir logs
- comparar payloads
- ler repeticoes
- acelerar uma primeira passada

Eles nao substituem a decisao final de `gpt-5.4`.

## 5. Quick Start end-to-end

Se voce quer validar a stack rapidamente e ter uma primeira demonstracao funcional:

### Passo 1: sincronizar o plugin

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\sync-to-codex.ps1"
```

### Passo 2: conferir se o plugin e os agentes chegaram no Codex

Cheque:

- `C:\Users\haise\.codex\plugins\you-obd-lab`
- `C:\Users\haise\.codex\plugins\cache\haise-local\you-obd-lab\local`
- `C:\Users\haise\.codex\agents`
- `C:\Users\haise\.codex\AGENTS.md`

### Passo 3: conferir perfis locais

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -ListProfiles
```

### Passo 4: validar endpoint local do Ollama

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile rapido -HealthCheck
```

### Passo 5: rodar uma primeira triagem local

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile analitico -Prompt "Compare estes payloads e liste drift contratual em 5 bullets."
```

### Passo 6: confirmar GPU quando o modelo suportar

```powershell
ollama ps
```

```powershell
nvidia-smi
```

### Passo 7: abrir o plugin no Codex

Exemplos:

- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para validar uma fixture do simulador`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para revisar contratos entre app, tester e simulador`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para resumir telemetria usando LM local e fechar com GPT-5.4`

## 6. Skills do plugin

### Skill-raiz

#### `you-obd-team`

Entrada padrao quando o usuario invoca `[@you-obd-lab](plugin://you-obd-lab@haise-local)`.

Papel:

- abrir a equipe real
- escolher ownership
- congelar contratos antes da implementacao

### Skills de coordenacao e risco

#### `you-orchestrator`

Use quando:

- a tarefa cruza mais de um repo
- ha contrato JSON, rota, evento ou ownership em jogo

Entregas esperadas:

- modulos tocados
- ownership por modulo
- contratos congelados
- riscos
- proximo owner

#### `you-reviewer`

Use quando:

- a tarefa precisa de revisao
- ha risco de regressao
- voce quer QA cruzado entre app, simulador, tester e plugin

#### `you-monorepo-auditor`

Use quando:

- o primeiro problema e orientacao
- voce quer entender impacto e consumidores antes de editar

#### `you-contract-guardian`

Use quando:

- ha drift de payload
- campo JSON mudou
- evento WebSocket mudou
- contrato de rota, DTO ou estado esta em risco

### Skills de validacao e telemetria

#### `you-test-conductor`

Use quando:

- o principal desafio e provar uma mudanca
- voce quer a menor sequencia segura de validacao

#### `you-telemetry-inspector`

Use quando:

- a verdade esta em logcat, serial, traces ou WebSocket
- voce precisa montar timeline e achar a primeira divergencia

### Skills de ownership tecnico

#### `you-obd-android-lab`

Skill ampla para o fluxo Android + simulador + celular + validacao OBD.

#### `you-android-gateway`

Ownership de:

- Android
- `ADB`
- BLE
- gateway do IKRO
- transporte de leituras para o tester

#### `you-obd-simulator`

Ownership de:

- `YouSimuladorOBD`
- perfis
- modos
- cenarios
- DTCs
- consistencia entre API e OBD observavel

#### `youautotester-lab`

Ownership de:

- `firmware/YouAutoTester`
- WebUI local
- API local
- WebSocket local
- `TestResult`
- `Reading`

## 7. Agentes customizados

Os agentes customizados ficam em `custom-agents/` e sao sincronizados para `C:\Users\haise\.codex\agents`.

### Base instalada

- `you-orchestrator`
- `you-reviewer`
- `you-android-gateway`
- `you-obd-simulator`
- `youautotester-lab`

### Modelos dos agentes

| Agente | Modelo | Papel |
| --- | --- | --- |
| `you-orchestrator` | `gpt-5.4` | coordenacao |
| `you-reviewer` | `gpt-5.4` | revisao |
| `you-android-gateway` | `gpt-5.3-codex` | Android e transporte |
| `you-obd-simulator` | `gpt-5.3-codex` | simulador |
| `youautotester-lab` | `gpt-5.3-codex` | tester |

### Forma correta de pensar esses agentes

Eles nao sao "bots magicos" independentes do Codex. Eles sao perfis especializados que ajudam o plugin a:

- separar ownership
- evitar dois especialistas no mesmo arquivo
- deixar handoff claro
- reforcar revisao independente quando houver risco

## 8. Ciclo de agentes e handoff

O desenho oficial do plugin e:

1. abrir com `you-orchestrator`
2. congelar ownership, contrato, risco e sequencia
3. chamar apenas o especialista necessario
4. fechar com `you-reviewer` quando o trabalho for nao trivial

Especialistas padrao:

- `youautotester-lab` para `firmware/YouAutoTester`
- `you-android-gateway` para Android, `ADB`, BLE e IKRO
- `you-obd-simulator` para simulador, oracle, cenarios e semantica OBD

Formato de handoff recomendado:

- Ownership:
- Contract frozen:
- Files affected:
- Validation:
- Risks:
- Next owner:

## 9. Instalacao e superficies locais

### Fonte de verdade do plugin

- `C:\www\you-obd-lab-plugin`

### Superficies locais sincronizadas

Hoje, apos `sync-to-codex.ps1`, o plugin pode existir em:

- `C:\Users\haise\.codex\plugins\you-obd-lab`
- `C:\Users\haise\.codex\plugins\cache\haise-local\you-obd-lab\local`
- `C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab`

Essas superficies existem por compatibilidade e pelo jeito como o Codex local resolve plugin home, cache e marketplace.

### Marketplaces locais

- `C:\Users\haise\.agents\plugins\marketplace.json`
- `C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json`

### Regras globais

- `C:\Users\haise\.codex\AGENTS.md`

## 10. Configuracoes e arquivos-chave

### Credenciais do simulador

Fontes aceitas:

- `scripts/local-api-credentials.json`
- `YOU_OBD_API_USER`
- `YOU_OBD_API_PASSWORD`
- `C:\www\YouSimuladorOBD\firmware\include\config.h`

### LLMs locais

Script central:

- `scripts/invoke-you-ollama-profile.ps1`

Perfis:

- `rapido` -> `qwen2.5-coder:7b`
- `analitico` -> `deepseek-r1:8b`
- `pesado` -> `gpt-oss:20b`

### Fixtures

Manifesto principal:

- `fixtures/lab-fixtures.json`

### Agentes

- `custom-agents/*.toml`

## 11. Scripts principais

### `scripts/sync-to-codex.ps1`

Publica o workspace atual no Codex local.

Hoje ele:

- sincroniza a arvore `.tmp`
- sincroniza o plugin home em `.codex/plugins`
- sincroniza o cache `haise-local`
- atualiza os marketplaces locais
- instala os agentes customizados
- atualiza a regra em `AGENTS.md`

### `scripts/sync-from-codex.ps1`

Traz de volta para o workspace o que estiver no diretorio do Codex.

### `scripts/invoke-you-obd-bench-validation.ps1`

Runner principal de validacao de bancada.

Pode:

- preparar simulador
- abrir app
- capturar screenshot
- coletar logcat
- validar oracle
- gerar relatorio final

### `scripts/invoke-you-obd-fixture-suite.ps1`

Roda varias fixtures em sequencia e gera sumario de suite.

### `scripts/collect-you-obd-lab-snapshot.ps1`

Gera snapshot operacional do laboratorio.

### `scripts/watch-you-obd-status.ps1`

Monitora o status da API do simulador em loop.

### `scripts/invoke-you-autocar-emulator-validation.ps1`

Valida o app em emulador reaproveitando o fluxo do `YouAutoCarvAPP2`.

### `scripts/invoke-you-ollama-profile.ps1`

Entry point para as LLMs locais.

Parametros centrais:

- `-Profile rapido|analitico|pesado`
- `-Prompt`
- `-PromptFile`
- `-HealthCheck`
- `-ListProfiles`
- `-AsJson`

Uso pratico:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile rapido -Prompt "Resuma esta evidencia em 5 bullets."
```

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile analitico -PromptFile "C:\www\you-obd-lab-plugin\tmp\prompt.txt"
```

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile pesado -HealthCheck -AsJson
```

## 12. Como validar Ollama e GPU

Checklist minima:

1. `ollama list`
2. `http://127.0.0.1:11434/api/tags`
3. `invoke-you-ollama-profile.ps1 -HealthCheck`
4. `ollama ps` durante inferencia
5. `nvidia-smi` durante inferencia

Sinais saudaveis:

- `model_installed = true`
- o endpoint local responde
- `ollama ps` mostra o modelo ativo
- `nvidia-smi` mostra `ollama.exe` na RTX 4070 quando houver offload de GPU

Leitura pratica por perfil:

- `rapido` e `analitico` costumam caber melhor na RTX 4070
- `pesado` pode usar caminho misto CPU/GPU
- o plugin nao depende da NPU

## 13. Fluxos recomendados

### Fluxo A: cenario de bancada completo

1. preparar simulador
2. abrir app Android
3. capturar `status` e `diagnostics`
4. ler UI e logcat
5. consolidar `report.md` e `report.json`

### Fluxo B: fixture repetivel

1. escolher `FixtureId`
2. rodar o runner com fixture
3. comparar contra oracle esperado
4. registrar falha por categoria

### Fluxo C: review de contrato

1. usar `you-monorepo-auditor` para mapa rapido
2. usar `you-orchestrator` para ownership
3. usar `you-contract-guardian` para congelar o contrato
4. revisar com `you-reviewer`

### Fluxo D: leitura de telemetria com LM local

1. separar a evidencia
2. chamar `invoke-you-ollama-profile.ps1`
3. deixar `gpt-5.4` fechar a leitura final

## 14. Como usar o plugin no Codex

Prompts uteis:

- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para abrir o laboratorio e congelar ownership antes de editar`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para validar uma fixture com evidencias de app, oracle e logcat`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para resumir logs com o perfil analitico e revisar o resultado com GPT-5.4`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para revisar drift de payload entre app, tester e simulador`

Quando usar cada skill:

- `you-monorepo-auditor` para se orientar antes de editar
- `you-contract-guardian` quando o risco principal for drift de contrato
- `you-test-conductor` quando a principal pergunta for "como provar isso"
- `you-telemetry-inspector` quando a verdade estiver em logcat, serial e WebSocket

## 15. Saidas e artefatos

O plugin costuma gerar:

- `report.md`
- `report.json`
- `suite-summary.md`
- `suite-summary.json`
- `api-status-before.json`
- `api-status-after.json`
- `api-diagnostics-before.json`
- `api-diagnostics-after.json`
- screenshot
- logcat bruto
- logcat filtrado
- inventario do device

## 16. Como as LLMs locais entram no fluxo

As skills ja apontam para o helper local quando faz sentido.

Exemplos reais:

- `you-test-conductor`
- `you-telemetry-inspector`
- `you-contract-guardian`
- `you-monorepo-auditor`

Padrao de uso:

1. modelo local faz a primeira condensacao
2. `gpt-5.4` revisa e fecha a interpretacao

Esse padrao e importante para evitar:

- alucinacao na decisao final
- assinatura de contrato sem revisao
- conclusao forte a partir de um resumo local fraco

## 17. Pack de fontes para NotebookLM

Pacote minimo:

- `README.md`
- `docs/you-obd-lab-complete-guide.md`
- `docs/notebooklm-video-brief.md`
- `docs/hybrid-local-stack-2026-04-09.md`
- `docs/ikro-android-youautotester-contract.md`

Perguntas boas para fazer ao NotebookLM:

- `Qual e a arquitetura do YOU OBD Lab em linguagem simples?`
- `Como o plugin usa GPT-5.4 e LLMs locais sem misturar autoridade final?`
- `Quais sao os agentes, o ownership de cada um e a sequencia ideal de trabalho?`
- `Que demo ao vivo melhor prova o valor do plugin?`
- `Quais sao os limites conhecidos e os pontos de operacao segura?`

## 18. Troubleshooting

### Plugin nao aparece

Cheque:

1. `C:\Users\haise\.codex\plugins\you-obd-lab`
2. `C:\Users\haise\.codex\plugins\cache\haise-local\you-obd-lab\local`
3. `C:\Users\haise\.agents\plugins\marketplace.json`
4. `C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json`

### Agentes nao entram

Cheque:

1. `C:\Users\haise\.codex\agents`
2. `C:\Users\haise\.codex\AGENTS.md`
3. `custom-agents/*.toml`

### Ollama nao responde

Cheque:

1. `http://127.0.0.1:11434/api/tags`
2. `ollama list`
3. `ollama ps`
4. `nvidia-smi`

### Android nao aparece

Cheque:

1. USB primeiro
2. fallback para `ADB over Wi-Fi`
3. `-PromoteUsbToWifi`
4. IP do device e porta `5555`

## 19. Limites conhecidos

- o plugin nao substitui `gpt-5.4` como modelo final
- `gpt-oss:20b` pode usar offload misto CPU/GPU em 8 GB de VRAM
- simulador, app e tester ainda podem divergir se o contrato nao estiver congelado
- parte da validacao depende de hardware real e evidencia de bancada

## 20. Como usar este material no NotebookLM

Se o objetivo e gerar um video ou material explicativo:

1. carregue este guia
2. carregue o `README`
3. carregue o guia do stack local hibrido
4. carregue os handoffs tecnicos que quiser citar

Ordem recomendada das fontes:

- `README.md`
- `docs/you-obd-lab-complete-guide.md`
- `docs/notebooklm-video-brief.md`
- `docs/hybrid-local-stack-2026-04-09.md`
- `docs/ikro-android-youautotester-contract.md`

## 21. Leituras relacionadas

- [../README.md](../README.md)
- [hybrid-local-stack-2026-04-09.md](hybrid-local-stack-2026-04-09.md)
- [ikro-android-youautotester-contract.md](ikro-android-youautotester-contract.md)
- [handoff-android-gateway-unstable-voltage.md](handoff-android-gateway-unstable-voltage.md)
- [handoff-simulator-unstable-voltage.md](handoff-simulator-unstable-voltage.md)
