# Handoff - Android Gateway - Tensao Instavel

## Skill aplicada

- `you-android-gateway`

## Objetivo

Preparar a rodada Android para validar o cenario `unstable_voltage_multi_module` do simulador OBD usando:

- adaptador/scanner real no telefone
- evidencia via `ADB`, screenshot e logcat
- separacao clara entre leitura OBD no app e canal independente do `YouAutoTester`

## Estado real da bancada Android

- `adb` funcional nesta maquina via:
  - `C:\Users\haise\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- device detectado:
  - serial `RXCY103X21F`
  - modelo `SM-S938B`
- app detectado:
  - pacote `com.youautocar.client2`
  - `versionName=1.2.10`
  - `versionCode=42`

Observacao:

- `adb` nao estava no `PATH` do shell, mas o binario local funciona

## Arquitetura do fluxo Android

### Trilha OBD real

Fluxo esperado para esta rodada:

- simulador externo prepara o oracle
- adaptador OBD real exposto ao Android via Bluetooth Classic
- app entra pela `DiagnosticsScreen`
- conexao passa por `ClassicBtController`
- transporte e comandos passam por `ObdClassicBtService`
- sessao de scanner tecnico usa `ScannerTransportBridge` + `ScannerSessionController`
- leituras clinicas de DTC, freeze frame e Mode 06 passam por `ObdCenterController`

Resumo:

```text
YouSimuladorOBD -> adaptador real -> Android BT Classic -> ObdClassicBtService
                                                -> ScannerTransportBridge -> ScannerSessionController
                                                -> ObdCenterController
```

### Trilha do `YouAutoTester`

Essa trilha e separada da OBD:

- `PartsTesterScreen`
- `PartsTesterWsService`
- WebSocket `ws://youautotester.local/ws`

Resumo:

```text
Android -> PartsTesterWsService -> ws://youautotester.local/ws -> YouAutoTester
```

Conclusao importante:

- o teste OBD do cenario de tensao nao depende do `YouAutoTester`
- o `YouAutoTester` entra apenas como evidencia eletrica complementar

## Modulos impactados

- Android conexao/pairing:
  - `apps/mobile/lib/features/diagnostics/screens/diagnostics_screen.dart`
  - `apps/mobile/lib/features/obd/presentation/controllers/classic_bt_controller.dart`
  - `apps/mobile/lib/features/obd/data/datasources/obd_classic_bt_service.dart`
- Android sessao scanner:
  - `apps/mobile/lib/features/obd/services/scanner_transport_bridge.dart`
  - `apps/mobile/lib/features/obd/presentation/controllers/scanner_session_controller.dart`
- Android leitura clinica:
  - `apps/mobile/lib/features/diagnostics/controllers/obd_center_controller.dart`
- Android <-> `YouAutoTester`:
  - `apps/mobile/lib/features/parts_tester/services/parts_tester_ws_service.dart`
  - `apps/mobile/lib/features/parts_tester/presentation/controllers/parts_tester_controller.dart`

## Contratos usados na rodada

### OBD / diagnostico

- `Mode 03`: DTC atual
- `Mode 02`: freeze frame
- `Mode 06`: monitor tests
- PID de tensao:
  - `0142` no fluxo live do scanner

### Sinais e logs esperados no app

- status `ecuReady` antes da leitura clinica
- logs do scanner:
  - `[ScannerBridge]`
  - `[ScannerSession]`
  - `[ProfilePolling]`
- logs do transporte:
  - `[OBD-Classic]`

### Contrato do `YouAutoTester`

Canal atual do app para o tester:

```json
{
  "cmd": "start_test",
  "part_type": "<tipo>",
  "os_code": "<opcional>"
}
```

Contrato exigido pelo firmware para `DMM_VOLTAGE`:

- `expected_min`
- `expected_max`
- opcionalmente `mode` e `unit`

Implicacao:

- o app Android atual nao fecha sozinho a rodada `DMM_VOLTAGE` no `YouAutoTester`

## Riscos principais

### 1. Trilha errada de transporte

O app suporta BLE e Classic, mas para esta rodada o trilho esperado e Bluetooth Classic com adaptador real.

Risco:

- conectar por BLE em um fluxo que deveria homologar o trilho Classic

### 2. Colisao entre polling e leitura diagnostica

`ObdCenterController` entra em modo exclusivo para ler DTC, freeze frame e monitor tests.

Risco:

- capturar evidencia com polling e leitura clinica competindo no serial

### 3. Contexto de oficina ausente

A `DiagnosticsScreen` bloqueia conexao em modo workshop quando falta contexto OBD.

Risco:

- tentar iniciar a rodada sem veiculo/OS/agendamento corretos

### 4. Confundir simulador externo com simulador interno do app

O app possui `ObdSimulatorService`, mas ele nao serve como prova desta rodada.

Risco:

- validar a UX em modo demo e concluir incorretamente sobre o cenario real

### 5. Bloqueio no `YouAutoTester`

O app mobile de `parts_tester` nao expoe hoje os tipos `DMM_*` nem envia a faixa exigida pelo firmware.

Risco:

- assumir integracao Android -> `YouAutoTester` pronta quando ela ainda esta parcial

## Plano de validacao Android

### Fase 1 - verdade do device

- confirmar device:
  - `& 'C:\Users\haise\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices`
- confirmar app instalado:
  - `& 'C:\Users\haise\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell pm list packages | Select-String 'com.youautocar.client2'`

### Fase 2 - entrada na trilha certa

- abrir `DiagnosticsScreen`
- garantir contexto de oficina/veiculo antes da conexao
- usar adaptador pareado em Bluetooth Classic
- evitar usar `ObdSimulatorService` ou trilha BLE se o objetivo for homologar o scanner real

### Fase 3 - evidencia OBD

- conectar ao adaptador ate `ecuReady`
- abrir o scanner tecnico
- confirmar leitura live de tensao e sensores basicos
- entrar no `Centro OBD`
- capturar:
  - `Mode 03` com expectativa de `P0562`
  - `Mode 02` com freeze frame apos qualificacao
  - `Mode 06` coerente com o cenario

### Fase 4 - evidencia Android

- screenshot da tela principal de diagnostico
- screenshot do `Centro OBD`
- logcat filtrado para:
  - `ScannerBridge`
  - `ScannerSession`
  - `OBD-Classic`

Comandos sugeridos:

```powershell
& 'C:\Users\haise\AppData\Local\Android\Sdk\platform-tools\adb.exe' logcat -d | Select-String 'ScannerBridge|ScannerSession|OBD-Classic'
& 'C:\Users\haise\AppData\Local\Android\Sdk\platform-tools\adb.exe' exec-out screencap -p > C:\www\you-obd-lab-plugin\fixtures\android-unstable-voltage.png
```

### Fase 5 - evidencia complementar do `YouAutoTester`

- opcional nesta rodada
- nao usar como criterio de aceite do contrato OBD
- se entrar:
  - injetar manualmente amostra no tester
  - rodar `DMM_VOLTAGE` com faixa explicita por canal compatível com o firmware

## Resultado esperado da rodada Android

- app conectado em trilha real de scanner
- `P0562` visivel no diagnostico
- freeze frame presente apos qualificacao
- leitura de tensao coerente com o oracle do simulador
- screenshots e logcat suficientes para comparar:
  - oracle do simulador
  - OBD real
  - UX Android

## Proximo handoff

### `youautotester-lab`

Pergunta objetiva para o proximo modulo:

- vamos adaptar o app para enviar `expected_min` e `expected_max` ao `YouAutoTester`
- ou vamos assumir que a prova de bancada do tester fica manual nesta tranche

## Limites desta rodada

Validado agora:

- device Android presente e autorizado
- app instalado no device
- trilha de codigo Android mapeada

Ainda nao validado nesta rodada:

- conexao ao adaptador real
- leitura OBD ao vivo do cenario
- screenshot real da rodada
- logcat da sessao real
