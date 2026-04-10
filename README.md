# YOU OBD Lab Plugin

![YOU OBD Lab](assets/app-icon.svg)

`YOU OBD Lab` e um plugin local do Codex para transformar o ecossistema YOU em um laboratorio repetivel de:

- validacao de simulador OBD
- observacao do app Android em celular real via `ADB`
- trabalho no `firmware/YouAutoTester`
- validacao de fixtures e cenarios
- revisao de contratos, telemetria e regressao
- triagem operacional com LLMs locais via `Ollama`

O plugin foi desenhado para trabalhar em conjunto com:

- `C:\www\YouSimuladorOBD`
- `C:\www\YouAutoCarvAPP2`
- `firmware/YouAutoTester`
- celular Android real
- adaptadores `ELM327` e `OBDLink`

## Leitura recomendada

Se voce quer uma visao rapida:

- leia este `README`

Se voce quer o manual completo, bom para estudo, repasse e NotebookLM:

- [docs/you-obd-lab-complete-guide.md](docs/you-obd-lab-complete-guide.md)

Se voce quer um material ja organizado para virar video:

- [docs/notebooklm-video-brief.md](docs/notebooklm-video-brief.md)

## Quick Start

Se voce quer sair do zero e provar que tudo esta vivo:

### 1. Sincronize o plugin para o Codex local

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\sync-to-codex.ps1"
```

### 2. Liste os perfis locais

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -ListProfiles
```

### 3. Valide o endpoint local do Ollama

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile rapido -HealthCheck
```

### 4. Rode uma triagem real com LM local

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile analitico -Prompt "Resuma este fluxo em 5 bullets e aponte possivel drift contratual."
```

### 5. Confirme uso de GPU quando aplicavel

```powershell
ollama ps
```

```powershell
nvidia-smi
```

### 6. Invoque o plugin no Codex

- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para abrir o laboratorio com ownership claro`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para validar uma fixture do simulador com evidencias`
- `Use [@you-obd-lab](plugin://you-obd-lab@haise-local) para revisar contratos entre app, tester e simulador`

## O que o plugin pode fazer

O plugin ajuda o Codex a:

- preparar cenarios no simulador via API
- validar o comportamento do app Android contra a API e o oracle do simulador
- comparar `API do simulador`, `OBD real` e `ADB/logcat/screenshots`
- trabalhar no `firmware/YouAutoTester` com ownership claro
- revisar contratos JSON, eventos WebSocket, rotas, DTOs e handoffs
- inspecionar telemetria e reduzir ruido de log
- coordenar validacao por fixture, por suite ou por bancada real
- usar LLMs locais para triagem, condensacao e comparacao inicial

Em resumo: o plugin pega um fluxo que normalmente fica espalhado entre memoria, scripts e tentativa-e-erro, e transforma isso em um laboratorio orientado por evidencia.

## Modelo de IA do plugin

O `YOU OBD Lab` e um plugin hibrido.

### Papel do `gpt-5.4`

`gpt-5.4` continua sendo o modelo principal para:

- orquestracao
- revisao final
- decisao de risco
- interpretacao final de contratos
- veredito final de validacao

### Papel das LLMs locais via Ollama

As LLMs locais entram como apoio operacional para:

- triagem inicial
- condensacao de logs
- comparacao de payloads
- resumo de repeticoes
- auditoria inicial antes da revisao final

Perfis locais suportados hoje:

| Perfil | Modelo | Uso principal |
| --- | --- | --- |
| `rapido` | `qwen2.5-coder:7b` | triagem curta e scratchpad operacional |
| `analitico` | `deepseek-r1:8b` | comparacao e primeira leitura mais cuidadosa |
| `pesado` | `gpt-oss:20b` | condensacao de escopo amplo e logs maiores |

Regra do plugin:

- LLM local ajuda
- `gpt-5.4` fecha o diagnostico e a decisao critica

Guia tecnico do stack local:

- [docs/hybrid-local-stack-2026-04-09.md](docs/hybrid-local-stack-2026-04-09.md)

## Como o plugin trabalha

Quando o usuario chama `@you-obd-lab`, o fluxo ideal e:

1. `you-obd-team` ou `you-orchestrator` abrem a coordenacao
2. ownership e contratos sao congelados antes da edicao
3. entra so o especialista necessario
4. LLM local pode fazer triagem inicial
5. `gpt-5.4` fecha risco, revisao e decisao final

Esse desenho evita:

- duas frentes mexendo no mesmo arquivo
- drift de contrato entre repos
- conclusao forte baseada apenas em resumo local

## Skills do plugin

O plugin hoje disponibiliza estas skills:

| Skill | Papel |
| --- | --- |
| `you-obd-team` | entrada padrao quando o usuario invoca `@you-obd-lab` |
| `you-orchestrator` | ownership, contratos, sequenciamento e handoff |
| `you-monorepo-auditor` | mapa rapido de impacto entre repos |
| `you-contract-guardian` | guardiao de contratos, payloads e eventos |
| `you-test-conductor` | plano e execucao de validacao |
| `you-telemetry-inspector` | leitura de logs, traces e timeline |
| `you-obd-android-lab` | skill ampla para fluxo Android + simulador + celular |
| `you-android-gateway` | Android, `ADB`, BLE, IKRO e transporte |
| `you-obd-simulator` | ownership do `YouSimuladorOBD` |
| `youautotester-lab` | ownership do `firmware/YouAutoTester` |
| `you-reviewer` | revisao final de regressao, risco e QA |

## Agentes customizados

O plugin tambem instala perfis de agentes customizados em `C:\Users\haise\.codex\agents`.

Agentes base:

- `you-orchestrator`
- `youautotester-lab`
- `you-android-gateway`
- `you-obd-simulator`
- `you-reviewer`

Modelos desses agentes:

- `you-orchestrator`: `gpt-5.4`
- `you-reviewer`: `gpt-5.4`
- especialistas de implementacao: `gpt-5.3-codex`

Quando o usuario invoca `[@you-obd-lab](plugin://you-obd-lab@haise-local)`, o comportamento esperado e:

1. abrir com `you-orchestrator`
2. congelar ownership e contratos
3. chamar so o especialista necessario
4. fechar com `you-reviewer` quando houver risco relevante

## O que entra e o que sai do laboratorio

Entradas comuns:

- prompt do Codex
- fixture selecionada
- endpoint da API do simulador
- logcat, screenshot e traces locais
- payloads JSON ou eventos WebSocket
- telemetria de bancada

Saidas comuns:

- `report.md`
- `report.json`
- `suite-summary.md`
- `suite-summary.json`
- snapshots da API
- resumo de logs com apoio local
- handoff tecnico com ownership, risco e proximo owner

## Fluxos mais importantes

### 1. Validacao de bancada completa

Use:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-obd-bench-validation.ps1" -FixtureId "can_kia_clean"
```

Esse fluxo pode:

- preparar o simulador
- abrir o app Android
- capturar `status` e `diagnostics`
- coletar screenshot e logcat
- emitir `report.md` e `report.json`

### 2. Suite de fixtures

Use:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-obd-fixture-suite.ps1" -FixtureIds "can_kia_clean","can_kia_dtc","can_thp_urban"
```

### 3. Snapshot do laboratorio

Use:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\collect-you-obd-lab-snapshot.ps1"
```

### 4. Triagem local com LLM

Use:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile rapido -Prompt "Resuma estes logs em 5 bullets."
```

### 5. Validacao de app em emulador

Use:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-autocar-emulator-validation.ps1" -Route /profile/settings -ExpectedText "Configuracoes","Versao em execucao:"
```

## Caminhos importantes

### Fonte do plugin

- `C:\www\you-obd-lab-plugin`

### Instalacao local do Codex

Hoje o plugin pode aparecer em mais de uma arvore local:

- `C:\Users\haise\.codex\plugins\you-obd-lab`
- `C:\Users\haise\.codex\plugins\cache\haise-local\you-obd-lab\local`
- `C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab`

O script `sync-to-codex.ps1` foi ajustado para manter essas superficies coerentes.

### Marketplaces locais

- `C:\Users\haise\.agents\plugins\marketplace.json`
- `C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json`

### Regras globais

- `C:\Users\haise\.codex\AGENTS.md`

## Credenciais e configuracao local

Fontes de verdade para credenciais do simulador:

- `scripts/local-api-credentials.json`
- `YOU_OBD_API_USER`
- `YOU_OBD_API_PASSWORD`
- `C:\www\YouSimuladorOBD\firmware\include\config.h`

Outras configuracoes importantes:

- manifesto de fixtures: `fixtures/lab-fixtures.json`
- helper de modelos locais: `scripts/invoke-you-ollama-profile.ps1`

## Como sincronizar o plugin

Para publicar o workspace atual no Codex local:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\sync-to-codex.ps1"
```

Esse script agora:

- sincroniza a arvore `.tmp` de compatibilidade
- sincroniza `C:\Users\haise\.codex\plugins\you-obd-lab`
- sincroniza o cache ativo `haise-local`
- atualiza os marketplaces locais
- instala os agentes customizados
- atualiza a regra global em `AGENTS.md`

## Exemplos de prompts

- `Use $you-obd-team para abrir a equipe real do laboratorio`
- `Use $you-orchestrator para coordenar uma mudanca entre app, simulador e plugin`
- `Use $you-test-conductor para validar esta fixture com evidencias`
- `Use $you-telemetry-inspector para resumir esta timeline de logcat e WebSocket`
- `Use $you-contract-guardian para revisar drift de payload`
- `Use $you-monorepo-auditor para mapear impacto entre repos`

## Pacote recomendado para NotebookLM

Se o objetivo e gerar video, onboarding ou narracao tecnica, carregue pelo menos:

- `README.md`
- `docs/you-obd-lab-complete-guide.md`
- `docs/notebooklm-video-brief.md`
- `docs/hybrid-local-stack-2026-04-09.md`
- `docs/ikro-android-youautotester-contract.md`

Ordem recomendada:

1. `README.md`
2. `docs/you-obd-lab-complete-guide.md`
3. `docs/notebooklm-video-brief.md`
4. `docs/hybrid-local-stack-2026-04-09.md`
5. `docs/ikro-android-youautotester-contract.md`

## Documentacao relacionada

- [docs/you-obd-lab-complete-guide.md](docs/you-obd-lab-complete-guide.md)
- [docs/notebooklm-video-brief.md](docs/notebooklm-video-brief.md)
- [docs/hybrid-local-stack-2026-04-09.md](docs/hybrid-local-stack-2026-04-09.md)
- [docs/ikro-android-youautotester-contract.md](docs/ikro-android-youautotester-contract.md)
- [docs/handoff-android-gateway-unstable-voltage.md](docs/handoff-android-gateway-unstable-voltage.md)
- [docs/handoff-simulator-unstable-voltage.md](docs/handoff-simulator-unstable-voltage.md)

## Estado atual

O plugin ja esta apto para:

- operar como hub multi-skill
- usar LLMs locais via Ollama
- manter `gpt-5.4` como modelo principal
- validar simulador, app Android e tester
- servir de base para documentacao, treinamento e material de video
