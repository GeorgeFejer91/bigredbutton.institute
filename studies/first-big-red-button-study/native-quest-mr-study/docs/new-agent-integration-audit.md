# New Agent Integration Audit

Current native-app audit for `New-Agent-Integration-Brief.md`, generated on 2026-06-13.

This project implements the public brief as a native Meta Spatial SDK contract, not by importing the Unity project or launching a separate questionnaire APK during participant flow. The participant-facing study remains one native Quest MR app with local headset exports and a final physical controller-contact press gate.

## Implemented Contract

| Brief area | Native implementation |
| --- | --- |
| Public repository boundary | The export records `agentIntegrationProtocol.sourceBriefRepository=MesmerPrism/the-big-red-button-institute` and `sourceBriefBranch=codex/brb-questionnaire-panel-bridge`, while `unityDependency=false`. |
| Questionnaire bridge | Current flow remains `in_process_spatial_panel` and `productCommunication=app_internal`. The export also records the external panel package and the exact `quest.questionnaire.v1` bridge constraints to use if the standalone panel is adopted later: explicit intent, `request_json`, caller-owned `content://` result URI, write grant, one-shot immutable broadcast `PendingIntent`, caller-side readback, and no ADB/public-storage/file/overlay/package-kill route. |
| Rusty XR broker | `rustyXrBrokerRequired=false`; no broker process is needed for the native study. |
| Direct Polar | Native BLE PMD ECG/RR is active as `directPolar.transport=native_ble_pmd_ecg_rr`, records both audio conditions, and routes heartbeat visual feedback through `HeartbeatPulseDriver`. |
| Direct LSL | Unity-compatible defaults are preserved in the disabled diagnostic scaffold: `HRV_Biofeedback`, `HRV`, channel `0`, threshold `0.5`, rising edge, and 250 ms minimum interval. LSL is not enabled until an Android-compatible `liblsl.so`/JNI path is added and headset-tested. |
| Button blink and press convergence | Heartbeat and sham feedback pulses use the blink/glow route only. External signals cannot satisfy the final gate. Final participant proof remains `controller_contact`, with hand contact recorded only as supplemental provenance. |
| Forbidden product mechanisms | Manifest/source/static/schema validation keep product flow free of `QUERY_ALL_PACKAGES`, `SYSTEM_ALERT_WINDOW`, public shared storage exchange, MediaStore exchange, `file://`, package-kill return flow, and overlay return flow. Development ADB scripts remain validation-only. |

## Validation Hooks

- Startup log marker: `BRB_AGENT_INTEGRATION_CONTRACT`.
- JSON export object: `agentIntegrationProtocol`.
- Schema gate: `tools/validate-export-schema.ps1 -Synthetic`.
- Static gate: `tools/validate-study.ps1 -SkipBuild`.
- Headset directional/export gate: `tools/run-quest-keyevent-questionnaire-validation.ps1` checks the exported protocol and startup marker on pulled Quest data.
- Local preflight evidence: `artifacts/local-preflight/20260613-024935/local-preflight-summary.json`, status `pass`, APK SHA-256 `F272AAECC705ED533198D5C35FD401B68141A8D72714DF82E9E09629EE2560FC`.

## Open External Gates

The software contract is implemented, but the overall study remains incomplete until the external hardware gates pass:

- Live Polar H10 PMD ECG smoke with a worn H10.
- Human controller-contact smoke on the modeled 3D button.
- Full two-condition physical controller-contact plus live-H10 export validation.

Run `tools/run-final-hardware-gates.ps1` with a headset operator and worn Polar H10 for the final evidence chain.
