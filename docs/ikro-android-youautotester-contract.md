# IKRO IK2029B -> Android Gateway -> YouAutoTester

## Objetivo

Definir o contrato oficial do fluxo de leitura DMM via IKRO IK2029B no ecossistema YOU, preservando compatibilidade com o `YouAutoTester` atual e reduzindo drift entre Android, firmware e plugin.

## Ownership

- Android: capture, normalize, forward, confirm, trigger test
- YouAutoTester: store sample, validate freshness, run DMM test, publish result
- Plugin: orchestrate and validate end-to-end evidence

## Vocabulário Canônico

### `mode`

- `voltage_dc`
- `current_dc`
- `resistance`
- `continuity`

### `unit`

- `V`
- `A`
- `Ohm`
- `state`

### `part_type`

- `DMM_VOLTAGE`
- `DMM_CURRENT`
- `DMM_RESISTANCE`
- `DMM_CONTINUITY`

## Contrato 1: `set_multimeter_sample`

Canal principal: WebSocket

Fallback: `POST /api/multimeter/sample`

```json
{
  "cmd": "set_multimeter_sample",
  "source": "ikro_ik2029b",
  "mode": "voltage_dc",
  "value": 12.64,
  "unit": "V",
  "valid": true,
  "timestamp_ms": 123456
}
```

### Campos obrigatórios

- `source`
- `mode`
- `value`
- `unit`
- `valid`

### Campo opcional

- `timestamp_ms`

## Contrato 2: `multimeter_sample_stored`

Evento de confirmação da sample aceita pelo `YouAutoTester`.

```json
{
  "event": "multimeter_sample_stored",
  "stored": true,
  "source": "ikro_ik2029b",
  "mode": "voltage_dc",
  "unit": "V",
  "value": 12.64,
  "valid": true,
  "source_timestamp_ms": 123456,
  "sample_revision": 17
}
```

### Regras

- Android só pode disparar `start_test` após esse ack
- `sample_revision` é recomendado para rastreabilidade e anti-reuse
- campos extras devem ser tratados de forma aditiva

## Contrato 3: `status`

O status do tester deve expor o snapshot atual da sample.

```json
{
  "event": "status",
  "fw_version": "x.y.z",
  "wifi": "connected",
  "ip": "192.168.1.20",
  "ssid": "YOU-LAB",
  "pending_os_code": "OS-4821",
  "pending_unlinked": 0,
  "multimeter": {
    "stored": true,
    "fresh": true,
    "age_ms": 420,
    "sample_revision": 17,
    "sample": {
      "source": "ikro_ik2029b",
      "mode": "voltage_dc",
      "value": 12.64,
      "unit": "V",
      "valid": true,
      "timestamp_ms": 987654,
      "source_timestamp_ms": 123456
    }
  }
}
```

## Contrato 4: `start_test`

```json
{
  "cmd": "start_test",
  "part_type": "DMM_VOLTAGE",
  "expected_min": 12.0,
  "expected_max": 14.4,
  "mode": "voltage_dc",
  "unit": "V",
  "os_code": "OS-4821"
}
```

### Regras

- `expected_min` e `expected_max` são obrigatórios para `DMM_VOLTAGE`, `DMM_CURRENT` e `DMM_RESISTANCE`
- para `DMM_CONTINUITY`, o contrato pode usar `1/1` explicitamente
- Android não deve enviar aliases fora do vocabulário canônico

## Contrato 5: `test_result`

```json
{
  "event": "test_result",
  "test_id": "abc-123",
  "part_type": "DMM_VOLTAGE",
  "verdict": "APROVADA",
  "approved": true,
  "notes": "Leitura recebida do gateway externo (ikro_ik2029b)",
  "tested_at": "2026-04-07T18:00:00Z",
  "sample_revision": 17,
  "sample_source": "ikro_ik2029b",
  "sample_age_ms": 420,
  "readings": [
    {
      "parameter": "voltage_dc",
      "measured": 12.64,
      "expected_min": 12.0,
      "expected_max": 14.4,
      "unit": "V",
      "passed": true
    }
  ]
}
```

### Regras

- `readings` deve continuar compatível com `TestResult` e `Reading`
- `sample_revision`, `sample_source` e `sample_age_ms` são aditivos e recomendados
- o resultado deve permitir provar qual sample alimentou o teste

## Sequência Oficial Do Fluxo

1. Android captura a leitura do IKRO
2. Android normaliza para o vocabulário canônico
3. Android envia `set_multimeter_sample`
4. Android espera `multimeter_sample_stored`
5. se não houver ack, tenta `POST /api/multimeter/sample`
6. Android consulta ou observa `status.multimeter`
7. Android só então envia `start_test`
8. YouAutoTester publica `test_result`
9. plugin valida ack, freshness e resultado final

## Política De Stale Sample

- sample sem ack não pode ser usada
- sample com `fresh=false` não pode ser usada
- retry não pode reutilizar silenciosamente a mesma sample sem rastreabilidade
- `sample_revision` ou contador interno é o mecanismo preferido

## Compatibilidade

- firmware deve aceitar campos extras sem quebrar payload antigo
- Android deve continuar compatível com `test_result` atual
- novos campos devem ser aditivos, não destrutivos

## Evidência Mínima Para Validação

- sample capturada no Android
- payload enviado ao tester
- ack `multimeter_sample_stored`
- snapshot `status.multimeter`
- `test_result` com rastreabilidade da sample
- evidência do plugin ou bancada ligando sample e resultado
