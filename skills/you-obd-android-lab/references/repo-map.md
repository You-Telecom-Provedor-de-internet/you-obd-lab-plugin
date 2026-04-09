# Repo Map

## Workspaces

- Simulator: `C:\www\YouSimuladorOBD`
- Android app: `C:\www\YouAutoCarvAPP2`

## Simulator Commands

- Build: `pio run` from `C:\www\YouSimuladorOBD\firmware`
- Size: `pio run -t size`
- Upload firmware: `pio run -t upload`
- Upload filesystem: `pio run -t uploadfs`

## Android Commands

- Analyze: `flutter analyze`
- Tests: `flutter test`
- APK debug build: `flutter build apk --debug`

Run Flutter commands from the app workspace, usually `C:\www\YouAutoCarvAPP2\apps\mobile`.

## Device Commands

- Detect phone: `adb devices`
- Wi-Fi fallback: `adb connect 192.168.1.99:5555`
- Promote USB to Wi-Fi: `adb -s <usb-serial> tcpip 5555`
- Logcat: `adb logcat`
- Screenshot: `adb exec-out screencap -p > file.png`
- App package in past validations: `com.youautocar.client2`

## Files Worth Checking First

### Simulator

- `firmware/src/web/web_server.cpp`
- `firmware/src/simulation/dynamic_engine.cpp`
- `firmware/src/simulation/diagnostic_scenario_engine.cpp`
- `firmware/include/vehicle_profiles.h`
- `docs/08-wifi-webui.md`
- `docs/14-diagnostic-scenarios.md`

### Android

- `apps/mobile/lib/features/diagnostics/`
- `apps/mobile/lib/features/obd/`
- `apps/mobile/lib/features/dashboard/`
- `README.md`
