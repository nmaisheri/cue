# Cue for Mac

A lightweight native macOS assistant with a horizontal, translucent floating window, incoming system-audio transcription, document context, and streamed answer suggestions.

## Current version

**1.2.2 (build 5)**. Download [Cue-Mac.zip](outputs/Cue-Mac.zip), extract it, and follow [Start Here](outputs/Start%20Here.md). The included binary is for Apple silicon on macOS 14 or later and is locally signed, not notarized.

## Features

- Incoming computer audio through ScreenCaptureKit and English transcription through Apple Speech.
- Streaming answers, model selection, a fast-answer preset, and follow-up context.
- Custom instructions and PDF, DOCX, RTF, or TXT attachments, with extracted-text preview and local persistence.
- Horizontal floating layout, adjustable backdrop opacity, menu bar controls, and a global show/hide shortcut.
- API credentials stored in macOS Keychain.

Full-screen sharing can include Cue; invisibility is not guaranteed. The app does not save audio recordings. See the guide for permissions and data handling.

## Repository contents

| Path | Contents |
| --- | --- |
| `outputs/Cue Source/` | Swift package, app source, icon, build script, and regression checks |
| `outputs/Cue Source/Tests/CueCoreTests/Fixtures/` | Synthetic Word document used by tests |
| `outputs/Cue-Mac.zip` | Latest packaged macOS app |
| `outputs/Start Here.md` | Setup, controls, troubleshooting, and verification notes |
| `CHANGELOG.md` | Summary of work completed across iterations |

Personal resumes, saved prompts, API keys, local app data, diagnostic logs, caches, and temporary builds are not included.

## Build

Install Apple's Command Line Tools, then run from this repository:

```sh
cd "outputs/Cue Source"
./build.sh
```

The app is written to `outputs/Cue.app`. There are no third-party package dependencies. The build uses the host architecture and signs the app locally; rebuilding may require refreshing macOS permissions.

## Run regression checks

```sh
cd "outputs/Cue Source"
swift run --disable-sandbox CueChecks
```

Checks cover transcript revisions, streamed response parsing, follow-up context, model and speed payloads, Word paragraph/table extraction, attachment persistence/removal, invalid documents, and document-only facts included in requests.

The current build and regression checks passed locally. Real model responses and the latest inactive-window click change have not been verified end to end; see the guide for the precise verification history. API model availability depends on your account.
