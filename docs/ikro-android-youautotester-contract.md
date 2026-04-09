# IKRO IK2029B -> Android Gateway -> YouAutoTester

## Objetivo

Definir o contrato oficial do fluxo de leitura DMM via IKRO IK2029B no ecossistema YOU, preservando compatibilidade com o `YouAutoTester` atual e reduzindo drift entre Android, firmware e plugin.

## Ownership

- Android: capture, normalize, forward, confirm, trigger test
- YouAutoTester: store sample, validate freshness, run DMM test, publish result
- Plugin: orchestrate and validate end-to-end evidence

## Politica Oficial De Identidade Da O.S.

- `service_order_id` e o identificador canonico de negocio quando presente no fluxo.
- `os_code` e um identificador humano e operacional. Ele pode entrar como fallback, mas nao substitui o UUID como verdade final.
- quando backend, tester ou app resolverem um `service_order_id` canonico a partir de `os_code`, esse UUID deve ser promovido e preservado nos consumidores seguintes.
- nenhum consumidor deve sobrescrever um `service_order_id` nao vazio com valor vazio, derivado ou apenas local.
- `test_id` e identidade de persistencia do teste. Ele nao substitui `service_order_id` nem prova sozinho o vinculo de negocio.

## Status verificado em 2026-04-09

Este documento mistura contrato alvo e contrato real. O comportamento provado no codigo hoje e:

- `set_multimeter_sample` esta implementado via WebSocket e `POST /api/multimeter/sample`
- o ack real `multimeter_sample_stored` retorna apenas `event`, `ok`, `stored`, `mode`, `unit` e `value`
- o `status` real do tester nao inclui `multimeter`; o snapshot completo da sample fica em `GET /api/multimeter/sample`
- quando o backend confirma a persistencia, o ack real devolve `tested_at` como ISO string auditavel
- o `test_result` real agora separa `tested_at` e `device_uptime_ms`
- `device_uptime_ms` carrega o valor bruto de `millis()` do tester
- quando nao ha ack canonico do backend, `test_result.tested_at` ainda pode sair numerico por compatibilidade legada
- o app mobile atual consome apenas `status` e `test_result`; ele nao espera `multimeter_sample_stored` rico nem envia `expected_min` e `expected_max`
- o app mobile passa a preferir `tested_at` em string e trata valor numerico legado como uptime, nao como epoch real
- o firmware ja trata `expected_min` e `expected_max` como obrigatorios para `DMM_VOLTAGE`, `DMM_CURRENT` e `DMM_RESISTANCE`
- `DMM_CONTINUITY` permanece compativel sem faixa explicita, usando a convencao `1/1` quando necessario

As secoes abaixo que usam `sample_revision`, `status.multimeter`, `sample_source` e `sample_age_ms` devem ser lidas como contrato alvo aditivo. Ja a separacao entre `tested_at` auditavel e `device_uptime_ms` faz parte do contrato real validado nesta rodada.

## Vocabulario Canonico

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

### Campos obrigatorios

- `source`
- `mode`
- `value`
- `unit`
- `valid`

### Campo opcional

- `timestamp_ms`

## Contrato 2: `multimeter_sample_stored`

Evento de confirmacao da sample aceita pelo `YouAutoTester`.

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

- Android so pode disparar `start_test` apos esse ack
- `sample_revision` e recomendado para rastreabilidade e anti-reuse
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
  "pending_service_order_id": "550e8400-e29b-41d4-a716-446655440000",
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

- `expected_min` e `expected_max` sao obrigatorios para `DMM_VOLTAGE`, `DMM_CURRENT` e `DMM_RESISTANCE`
- para `DMM_CONTINUITY`, o contrato pode usar `1/1` explicitamente
- Android nao deve enviar aliases fora do vocabulario canonico

## Contrato 5: `test_result`

```json
{
  "event": "test_result",
  "test_id": "abc-123",
  "part_type": "DMM_VOLTAGE",
  "verdict": "APROVADA",
  "approved": true,
  "notes": "Leitura recebida do gateway externo (ikro_ik2029b)",
  "service_order_id": "550e8400-e29b-41d4-a716-446655440000",
  "os_code": "OS-4821",
  "tested_at": "2026-04-07T18:00:00Z",
  "device_uptime_ms": 987654,
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

- `readings` deve continuar compativel com `TestResult` e `Reading`
- `service_order_id`, quando presente, e a referencia canonica do teste e deve prevalecer sobre qualquer `os_code`
- `os_code` continua util para UX, bancada e confirmacao humana, mas nao deve competir com o UUID como verdade final
- `tested_at` deve ser tratado como horario auditavel apenas quando vier em string canonica
- `device_uptime_ms` e a telemetria bruta do dispositivo e nao deve ser reinterpretado como horario real
- consumidores que ainda receberem `tested_at` numerico por compatibilidade nao devem converte-lo para epoch
- `sample_revision`, `sample_source` e `sample_age_ms` sao aditivos e recomendados
- o resultado deve permitir provar qual sample alimentou o teste

## Sequencia Oficial Do Fluxo

1. Android captura a leitura do IKRO
2. Android normaliza para o vocabulario canonico
3. Android envia `set_multimeter_sample`
4. Android espera `multimeter_sample_stored`
5. se nao houver ack, tenta `POST /api/multimeter/sample`
6. Android consulta ou observa `status.multimeter`
7. Android so entao envia `start_test`
8. YouAutoTester publica `test_result`
9. plugin valida ack, freshness, identidade de O.S. e resultado final

## Politica De Stale Sample

- sample sem ack nao pode ser usada
- sample com `fresh=false` nao pode ser usada
- retry nao pode reutilizar silenciosamente a mesma sample sem rastreabilidade
- `sample_revision` ou contador interno e o mecanismo preferido

## Compatibilidade

- firmware deve aceitar campos extras sem quebrar payload antigo
- Android deve continuar compativel com `test_result` atual
- novos campos devem ser aditivos, nao destrutivos
- `os_code` pode continuar entrando como fallback, mas `service_order_id` deve ser promovido como identidade final quando resolvido

## Evidencia Minima Para Validacao

- sample capturada no Android
- payload enviado ao tester
- ack `multimeter_sample_stored`
- snapshot `status.multimeter`
- `test_result` com `test_id`, `service_order_id` e `os_code` coerentes
- evidencia do plugin ou bancada ligando sample e resultado
