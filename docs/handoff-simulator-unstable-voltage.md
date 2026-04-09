# Handoff - Simulador OBD - Cenario Base de Tensao Instavel

## Skill aplicada

- `you-obd-simulator`

## Objetivo

Definir um cenario-base repetivel para uma tarefa que cruza:

- simulador OBD como oracle
- Android como consumidor OBD e evidencia de UX
- `YouAutoTester` como plano de validacao eletrica complementar

## Cenario proposto

- Perfil: `peugeot_308_16thp`
- Protocolo: `CAN 11b 500k` via perfil
- Modo: `SIM_IDLE` (`id = 1`)
- Cenario: `unstable_voltage_multi_module`
- DTC esperado quando persistente: `P0562`
- Intencao:
  - gerar oscilacao de tensao visivel no app
  - produzir alerta eletrico coerente no oracle
  - permitir comparacao com teste de tensao no `YouAutoTester`

## Motivo da escolha

Esse cenario encosta nos tres planos sem adicionar ruido de dirigibilidade:

- no simulador, a falha mexe em `battery_voltage` e modulos secundarios
- no Android, o `Centro OBD` consegue observar DTC, freeze frame e monitor tests
- no `YouAutoTester`, a validacao de tensao pode servir como prova complementar da bancada

`SIM_IDLE` foi escolhido para reduzir variaveis de movimento e deixar a leitura eletrica mais facil de comparar.

## Setup sugerido

Assumindo o simulador acessivel em `http://<SIMULADOR>`:

```powershell
curl.exe -u youobd-core:YouOBD.RevA@2026#Core http://<SIMULADOR>/api/status
curl.exe -u youobd-core:YouOBD.RevA@2026#Core -H "Content-Type: application/json" -d "{\"id\":\"peugeot_308_16thp\"}" http://<SIMULADOR>/api/profile
curl.exe -u youobd-core:YouOBD.RevA@2026#Core -H "Content-Type: application/json" -d "{\"id\":1}" http://<SIMULADOR>/api/mode
curl.exe -u youobd-core:YouOBD.RevA@2026#Core -H "Content-Type: application/json" -d "{\"id\":\"unstable_voltage_multi_module\"}" http://<SIMULADOR>/api/scenario
curl.exe -u youobd-core:YouOBD.RevA@2026#Core http://<SIMULADOR>/api/diagnostics
```

## Oracle esperado

Em `GET /api/status`:

- `protocol_id = 0`
- `profile_id = "peugeot_308_16thp"`
- `scenario_id = "unstable_voltage_multi_module"`
- `scenario_numeric_id = 5`
- `sim_mode = idle`
- variacao perceptivel em `battery_voltage`

Em `GET /api/diagnostics`:

- `scenario_id = "unstable_voltage_multi_module"`
- `active_faults` com falhas de tensao/modulo
- alerta eletrico principal coerente
- `P0562` quando a falha qualificar
- `freeze_frame` disponivel depois da qualificacao do primeiro DTC efetivo

## Ownership por modulo

- Simulador OBD:
  - preparar o cenario e congelar a verdade do oracle
  - confirmar `status`, `diagnostics`, `freeze_frame` e DTC
- Android OBD/diagnostics:
  - validar leitura real no app via scanner/adaptador
  - confirmar se `Mode 03`, `Mode 02` e `Mode 06` batem com o oracle
- `YouAutoTester`:
  - validar tensao como prova complementar da bancada
  - usar leitura de multimetro para confrontar a hipotese de tensao instavel

## Risco principal ja identificado

Hoje o app Android nao fecha sozinho o fluxo `DMM_VOLTAGE` com o `YouAutoTester`.

Motivos:

- a UI mobile atual de `parts_tester` nao expoe tipos `DMM_*`
- o cliente WS mobile envia apenas `cmd`, `part_type` e `os_code`
- o firmware do `YouAutoTester` exige `expected_min` e `expected_max` para `DMM_VOLTAGE`

Implicacao:

- a validacao `YouAutoTester` desta rodada deve ser feita por rota manual ou ajuste de contrato antes do handoff Android -> tester

## Checklist de validacao

### 1. Oracle

- ler `GET /api/status` antes e depois do setup
- ler `GET /api/diagnostics` ate o cenario qualificar
- registrar `battery_voltage`, `scenario_id`, `health_score`, `active_faults`, `dtcs`

### 2. OBD externo

- conectar adaptador real no Android
- abrir o fluxo de diagnostico/OBD
- confirmar presenca de `P0562`
- confirmar leitura coerente de tensao e eventual `freeze frame`

### 3. Android UX

- capturar screenshot da tela de diagnostico
- coletar `adb logcat` da sessao
- registrar o que o usuario realmente viu no `Centro OBD`

### 4. `YouAutoTester`

- se a rodada incluir prova eletrica, injetar amostra de tensao pelo endpoint local do tester
- usar uma faixa explicita para `DMM_VOLTAGE`
- tratar o resultado como evidencia complementar, nao como prova do contrato OBD

## Handoff recomendado

### Proximo: `you-android-gateway`

Entradas do handoff:

- cenario fixado em `unstable_voltage_multi_module`
- perfil `peugeot_308_16thp`
- modo `SIM_IDLE`
- expectativa de `P0562` e `freeze_frame`
- risco aberto no contrato Android <-> `YouAutoTester` para `DMM_VOLTAGE`

### Depois: `youautotester-lab`

Objetivo do proximo modulo:

- decidir se o app vai passar `expected_min`, `expected_max`, `mode` e `unit`
- ou se a rodada de bancada vai usar endpoint HTTP/WS manual para o tester

## Limite de validacao atual

Este handoff foi definido por leitura de codigo e documentacao local.

Ainda nao foi validado nesta rodada:

- em API real do simulador
- com adaptador/scanner real
- no celular Android
- no `YouAutoTester`
