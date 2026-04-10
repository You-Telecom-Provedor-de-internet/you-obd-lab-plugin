# NotebookLM Video Brief - YOU OBD Lab

## Objetivo deste arquivo

Este documento existe para servir como fonte direta para `NotebookLM`, roteiro de video, apresentacao ou onboarding.

Ele resume o plugin em linguagem clara e sequenciada.

## Frase curta para abrir o video

`YOU OBD Lab` e um plugin local do Codex que transforma o ecossistema YOU em um laboratorio de validacao assistido por IA, ligando simulador OBD, app Android, firmware do tester, evidencias de bancada e LLMs locais.

## O que o plugin e

O plugin nao e so um script.

Ele junta:

- skills especializadas
- agentes com ownership claro
- scripts de validacao
- fixtures
- telemetria
- suporte a modelos locais via Ollama

## Problema que ele resolve

Antes do plugin:

- validacao dependia de memoria
- ownership ficava difuso
- logs ficavam sem timeline
- contratos podiam derivar entre app, simulador e tester

Depois do plugin:

- ownership fica claro
- contratos podem ser congelados antes de editar
- evidencias saem organizadas
- o Codex pode validar por fixture, por bancada ou por telemetria
- modelos locais ajudam na triagem inicial

## Sistema que ele cobre

- `YouSimuladorOBD`
- `YouAutoCarvAPP2`
- `firmware/YouAutoTester`
- celular Android real via `ADB`
- adaptadores OBD reais
- API e oracle do simulador

## Modelo de IA

O plugin usa um modelo hibrido.

### Camada 1: `gpt-5.4`

Responsavel por:

- orquestracao
- revisao final
- risco
- decisao tecnica final

### Camada 2: Ollama local

Responsavel por:

- triagem
- condensacao
- comparacao inicial
- apoio operacional

Perfis:

- `rapido` -> `qwen2.5-coder:7b`
- `analitico` -> `deepseek-r1:8b`
- `pesado` -> `gpt-oss:20b`

Mensagem importante para o video:

`As LLMs locais ajudam, mas o veredito final continua no GPT-5.4.`

## Estrutura de agentes

O plugin pode trabalhar como equipe.

### Coordenacao

- `you-orchestrator`

### Especialistas

- `youautotester-lab`
- `you-android-gateway`
- `you-obd-simulator`

### Revisao

- `you-reviewer`

## Estrutura de skills

As skills mais importantes para explicar no video sao:

- `you-obd-team`
- `you-orchestrator`
- `you-test-conductor`
- `you-telemetry-inspector`
- `you-contract-guardian`
- `you-monorepo-auditor`

## O que voce pode demonstrar ao vivo

### Demo 1: fixture de bancada

Mostrar:

- o simulador sendo preparado
- o app Android sendo aberto
- a geracao de `report.md` e `report.json`

### Demo 2: telemetria com IA local

Mostrar:

- um arquivo de log ou `ws-test-result.json`
- o plugin chamando `invoke-you-ollama-profile.ps1`
- o perfil `analitico` resumindo a evidencia
- depois explicar que `gpt-5.4` fecha o diagnostico

### Demo 3: ownership

Mostrar:

- `you-orchestrator` congelando contrato
- especialista assumindo ownership
- `you-reviewer` entrando no final

## Frases fortes para a narrativa

- `O plugin nao substitui o engenheiro; ele organiza o laboratorio.`
- `O plugin nao substitui o GPT-5.4; ele usa modelos locais para acelerar a primeira passada.`
- `O valor do YOU OBD Lab nao esta num script isolado, mas na combinacao entre ownership, evidencias e validacao repetivel.`

## Roteiro sugerido para um video

### Capitulo 1 - O problema

Explicar o caos sem plugin:

- muitos repos
- muito hardware
- logs demais
- ownership pouco claro

### Capitulo 2 - A arquitetura

Mostrar:

- app
- simulador
- tester
- Android
- OBD real
- plugin

### Capitulo 3 - As skills e os agentes

Mostrar:

- `you-obd-team`
- `you-orchestrator`
- especialistas
- reviewer

### Capitulo 4 - IA hibrida

Mostrar:

- `gpt-5.4` como cerebro principal
- Ollama como apoio local
- perfis `rapido`, `analitico` e `pesado`

### Capitulo 5 - A validacao real

Mostrar:

- fixture
- bench validation
- relatorio
- telemetria

### Capitulo 6 - Porque isso importa

Fechar com:

- repetibilidade
- rastreabilidade
- menos regressao escondida
- melhor uso de IA no fluxo de engenharia

## Arquivos que valem entrar no NotebookLM junto com este

- `README.md`
- `docs/you-obd-lab-complete-guide.md`
- `docs/hybrid-local-stack-2026-04-09.md`
- `docs/ikro-android-youautotester-contract.md`

## Ordem recomendada das fontes

1. `README.md`
2. `docs/you-obd-lab-complete-guide.md`
3. `docs/notebooklm-video-brief.md`
4. `docs/hybrid-local-stack-2026-04-09.md`
5. `docs/ikro-android-youautotester-contract.md`

## Perguntas boas para fazer ao NotebookLM

- `Explique o YOU OBD Lab como se fosse um laboratorio assistido por IA para um publico tecnico.`
- `Resuma a arquitetura do plugin em 6 capitulos para um video de 8 a 12 minutos.`
- `Destaque o papel de GPT-5.4 versus os modelos locais do Ollama.`
- `Liste os agentes, suas responsabilidades e uma sequencia segura de demonstracao.`
- `Quais demos ao vivo melhor mostram o valor de ownership, evidencias e validacao repetivel?`

## Pontos que o video nao deve confundir

- o plugin nao troca o `gpt-5.4` por modelo local
- LLM local ajuda na triagem, nao no veredito final
- o valor principal nao e "ter IA", mas ter ownership, evidencias e repetibilidade
- o plugin e mais forte quando junta app, simulador, tester e bancada real

## Mensagem final sugerida

`YOU OBD Lab e um laboratorio de validacao assistido por IA, com ownership claro, evidencia rastreavel e um modelo hibrido onde GPT-5.4 pensa e revisa, enquanto os modelos locais aceleram a operacao.`
