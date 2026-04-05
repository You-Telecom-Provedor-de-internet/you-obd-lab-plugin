# API Oracle

Use the simulator API as the internal oracle while keeping real OBD as the compatibility path.

## Main Endpoints

- `GET /api/status`
- `GET /api/diagnostics`
- `GET /api/profiles`
- `GET /api/scenarios`
- `POST /api/profile`
- `POST /api/protocol`
- `POST /api/mode`
- `POST /api/scenario`
- `POST /api/params`
- `POST /api/dtcs/add`
- `POST /api/dtcs/remove`
- `POST /api/dtcs/clear`

## What `/api/status` is for

Use it for quick truth:

- active protocol
- profile id and selected profile metadata
- current sensor snapshot
- active mode
- VIN
- device and OTA context

## What `/api/diagnostics` is for

Use it for rich diagnosis and app comparison:

- effective DTC list
- active faults
- alerts
- anomalies
- probable root cause
- freeze frame
- freeze frame history
- scenario id
- control layers
- precedence notice and message
