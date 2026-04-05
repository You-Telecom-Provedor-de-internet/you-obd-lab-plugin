# YOU OBD Lab Plugin

Workspace fonte do plugin local do Codex para trabalhar com o ecossistema YOU em bancada:

- `YouSimuladorOBD`
- `YouAutoCarvAPP2`
- celular Android real via `ADB`
- adaptadores `ELM327` e `OBDLink`

## Objetivo

Este plugin existe para ajudar o Codex a:

- preparar cenarios no simulador via API
- validar comportamento real via OBD
- acompanhar o app Android no celular
- comparar `API do simulador`, `OBD real` e `UI/logs do app`

Em outras palavras, ele transforma o Codex em um laboratorio de validacao do ecossistema.

## Workspace fonte

Este workspace agora e a fonte de verdade do plugin:

- `C:\www\you-obd-lab-plugin`

## Localizacao ativa no Codex

Nesta maquina, a instalacao ativa do plugin esta em:

- `C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab`

O marketplace lido pela interface do Codex esta em:

- `C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json`

## Estrutura

- `.codex-plugin/plugin.json`
- `CHANGELOG.md`
- `assets/you-obd-lab-small.svg`
- `assets/app-icon.svg`
- `scripts\sync-to-codex.ps1`
- `scripts\sync-from-codex.ps1`
- `scripts/collect-you-obd-lab-snapshot.ps1`
- `scripts/watch-you-obd-status.ps1`
- `skills/you-obd-android-lab/SKILL.md`
- `skills/you-obd-android-lab/references/repo-map.md`
- `skills/you-obd-android-lab/references/api-oracle.md`
- `skills/you-obd-android-lab/references/validation-playbook.md`

## Skill principal

O plugin expoe a skill:

- `you-obd-android-lab`

Ela foi feita para tarefas que cruzam:

- `C:\www\YouSimuladorOBD`
- `C:\www\YouAutoCarvAPP2`

## Como usar

Exemplos de prompts:

- `Use $you-obd-android-lab para validar o simulador com o app Android e o celular real`
- `Compare API, OBD real e UI do app em um teste de regressao`
- `Prepare um cenario no simulador e valide o fluxo no YouAutoCarvAPP2`

## Modelo mental

O plugin trabalha com tres verdades:

1. `API do simulador` = plano de controle e oracle interno
2. `OBD real` = compatibilidade real com scanner/app
3. `ADB/logcat/screenshots` = o que o app Android exibiu

## Quando usar

Use este plugin quando a tarefa envolver pelo menos um destes casos:

- validar protocolo `CAN`, `ISO 9141-2`, `KWP 5-baud` ou `KWP Fast`
- preparar perfis, modos, cenarios e DTCs no simulador
- testar o `YouAutoCarvAPP2` com adaptador real
- comparar dados da API com o que veio pela ECU simulada
- coletar evidencias em bancada

## Scripts uteis

Publicar o workspace para o diretorio ativo do Codex:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\sync-to-codex.ps1"
```

Trazer de volta o plugin ativo do Codex para o workspace:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\sync-from-codex.ps1"
```

Snapshot completo de bancada:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab\scripts\collect-you-obd-lab-snapshot.ps1"
```

Monitor de status da API:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab\scripts\watch-you-obd-status.ps1"
```

## Troubleshooting

Se o plugin nao aparecer na interface:

1. confirme se `you-obd-lab` existe em `C:\Users\haise\.codex\.tmp\plugins\plugins\`
2. confirme se ele esta listado em `C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json`
3. feche e abra o Codex novamente

## Relacao com o projeto

O plugin e local ao ambiente Codex. A documentacao de uso no projeto esta em:

- `C:\www\YouSimuladorOBD\docs\18-codex-plugin-you-obd-lab.md`

## Fluxo recomendado de manutencao

1. editar o plugin em `C:\www\you-obd-lab-plugin`
2. rodar `sync-to-codex.ps1`
3. reabrir o Codex se necessario
4. validar o comportamento do plugin

Assim o plugin deixa de ficar "preso" so no diretorio interno do Codex.
