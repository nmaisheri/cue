# Cue for Mac

A small native menu bar app for incoming interview questions and suggested answers, with a wide, transparent floating window. Built for this Apple silicon Mac, with macOS 14 or later. No browser runtime, third-party packages, account server, or audio recording files.

## Start

1. Open **Cue.app** in this folder. You can move it to Applications first if you prefer; grant permissions after choosing its permanent location.
2. In Setup, add your instructions: role, job description, interviewer priorities, and preferred answer style.
3. Attach your resume as PDF, DOCX, TXT, or RTF. The file must contain readable text; scanned PDFs need OCR first. After reading, Cue shows a success label and a “View extracted document text” preview. The extracted text is saved locally and restored when you reopen Cue. Remove it with the button beside its filename.
4. Paste an OpenAI API key and select **Save**. Obtain one at https://platform.openai.com/api-keys with API billing enabled. A ChatGPT subscription does not supply this app's API usage. The key is stored in macOS Keychain.
5. Select **Done with setup**, then **Start listening**. macOS will request Speech Recognition and Screen & System Audio Recording access. Enable Cue under System Settings → Privacy & Security if needed, then quit and reopen it if macOS requests that.

Cue captures computer output, including incoming call audio, rather than your microphone. It currently transcribes English. Use headphones and pause unrelated videos or music, since all system audio is included.

## Model and speed

Your API key authorizes requests and billing; it does not choose the model. Select **Answer model** in Setup. The choice is saved and shown in the main window:

- **GPT-6 Sol** (`gpt-6-sol`) is the default, with reasoning disabled to prioritize speed. This update switches existing installations to Sol and Fast answers once; later manual choices are remembered.
- **GPT-5.6 Luna** (`gpt-5.6-luna`) remains a lightweight alternative, also with reasoning disabled.
- **GPT-4.1 mini** (`gpt-4.1-mini`) is the previous model and remains an alternative.

Changing models affects the next answer. Cue never silently switches models if a request fails; choose another model if your key lacks access. Each answer displays the model requested and measured time to first nonempty text. That measurement starts when the API request is sent and excludes transcription and the pause before sending.

**Fast answers** is on by default: Cue waits 0.9 seconds without a transcript change, requests about 50–90 words, caps output at 320 tokens, and streams text immediately as it arrives. Turning it off restores the 2.2-second wait and a 650-token cap for fuller answers. Faster triggering may start an answer during an interviewer's mid-question pause. You can turn off Auto-answer and press ⌘Return to control exactly when a request starts.

These settings prioritize speed, but no fixed response time is guaranteed. Audio transcription, network conditions, model load, and your prompt all affect the result. Real API latency has not been benchmarked with your key. The speed preset does not purchase priority processing.

Model references: [GPT-6 Sol](https://developers.openai.com/api/docs/models/gpt-6-sol), [GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna), [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini), [latency optimization](https://developers.openai.com/api/docs/guides/latency-optimization).

## Layout and transparency

Cue opens as a wide horizontal window, with incoming questions on the left and suggested answers on the right. Both panes scroll independently. The default window is 1040 × 390 points and can be resized down to 780 × 300.

Use the **Backdrop** slider in the header to adjust the background opacity from 30% to 95%. Lower values let you see more of the speaker and their screen through Cue; text stays solid. The setting is remembered between launches. There is no background blur. Drag empty space in the header to reposition the window, for example along the bottom of your call. The setup button opens instructions, resume attachment, and API settings separately.

## During a call

- **Auto-answer** generates after approximately 0.9 seconds without a transcript change in Fast answers mode (2.2 seconds with Fast answers off). Longer pauses within a question can trigger early; turn Auto-answer off and press **⌘Return** for manual timing.
- Incoming words appear under **Incoming question**. Answers stream below and remain visible while the next question arrives.
- Type a question or correction in the bottom field, then click the arrow or press **⌘Return**.
- Follow-ups use the latest 12 question/answer turns plus your instructions and resume. Previous suggested answers are context, not proof of what you actually said. Your microphone is not transcribed; type your actual response when that distinction matters.
- **⌘L** starts/stops listening while Cue is focused. **⌘⇧Space** shows/hides Cue globally. The menu bar waveform icon also offers Show/Hide, Start/Stop, and Quit.
- Closing or hiding the window keeps listening active. **Stop listening** ends capture; **Quit Cue** ends the app. Stopping listening does not cancel an answer already being generated; use the separate Stop button for that.
- The reset button clears the current conversation while retaining your setup for this launch. The app retains at most 40 turns in memory.

## Visibility

Cue has a floating window and no Dock icon, but **it is not guaranteed invisible to screen capture**. Modern macOS screen sharing can capture floating windows. Share a specific application/window that excludes Cue, or keep Cue on a separate display that is not being shared. Confirm with your call app's sharing preview before relying on either arrangement. macOS permission indicators are not hidden.

## Data and storage

- Your instructions are saved in local app preferences. The API key is saved only in Keychain and can be removed in Setup.
- Extracted attachment text and its filename are saved in ~/Library/Application Support/Cue/attachment.json until you remove the attachment. Conversation history remains in memory and disappears when you quit. Original files are never changed.
- Answer requests send your instructions, extracted resume text, the current question, and bounded recent conversation to OpenAI using HTTPS. Requests set `store: false`; provider retention policies still apply.
- Audio goes through Apple Speech. Cue requests on-device recognition when the recognizer supports it; otherwise Apple may process it online. Apple Speech determines on-device availability when listening starts.
- Cue does not save or upload screenshots, video, or audio recording files. It registers only an audio output with ScreenCaptureKit.

## If something does not work

- **No answers:** Add a valid API key, enable API billing, and check the error shown in Cue. The default model is `gpt-6-sol`; choose `gpt-4.1-mini` in Setup if preferred. The app does not automatically retry failed API requests.
- **No incoming words:** Check audio permissions, confirm that sound is playing through this Mac, and check English speech recognition availability. Stop/start listening after a call or audio-device change.
- **Permissions changed:** macOS may require quitting and reopening Cue. Rebuilding or moving a locally signed app may also require granting access again.
- **Resume empty:** Export a text-based PDF or TXT copy. Cue rejects empty files and files above 10 MB or 40,000 extracted characters.
- **Shortcut conflict:** Use the menu bar icon if another app owns ⌘⇧Space.

## Build and verification

This is a locally built, ad-hoc-signed app, not an Apple-notarized distribution. Its full source is in **Cue Source**. Run `./build.sh` there to rebuild using Apple Command Line Tools. The build uses temporary caches and has no downloaded dependencies. A build on an Intel Mac produces an Intel app.

The release build and local code signature were checked, including a fresh extraction of the ZIP. Automated checks cover partial-transcript revisions, segment rollover, streaming text and error parsing, follow-up context, and bounded history, selected-model request payloads, disabled reasoning, and speed settings. The native setup and horizontal interview layouts were inspected on this Mac. The backdrop slider was exercised successfully, changing the saved opacity from 62% to 55%. A stalled older test process was restarted; the updated app responded to setup and transparency controls. The model-selector update was compiled and request-tested without restarting the user’s populated live session. Live call transcription and real OpenAI answers require your permissions and API key and have not been verified end to end.

To run the source checks without full Xcode:

```sh
swift run --disable-sandbox CueChecks
```

Implementation references: [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [Apple window-sharing limitations](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum), [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat), [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini).

## Listening fix in 1.2.1

This build removes blocking Keychain access from startup. Use **Unlock saved key** in Setup when you need the saved API key; transcription does not need it. macOS may request approval for the rebuilt app to access the existing key. Saved instructions and the Keychain item are preserved. Speech permission requests now time out with a specific message rather than leaving the interface on Connecting indefinitely.

If recording permission is enabled but fails after an update, macOS may still be authorizing an older locally signed build. Quit Cue, remove its old entry from Screen & System Audio Recording, add the current Cue.app, then reopen it. This issue was confirmed in the macOS permission log. Keep only the current app copy.

## Attachment and click fixes in 1.2.2

Reattach your document once after updating: older releases did not save it between launches. Open “View extracted document text” to verify the facts Cue has read. Supported formats are text-based PDF, DOCX, TXT, and RTF, up to 10 MB and 40,000 characters. The full accepted text is included with every answer request. A relevant document fact does not have to be repeated in your prompt. Explicit factual corrections in your prompt still take priority.

The window now accepts the first click on controls while another app is active, and decorative borders do not intercept pointer input. Local regression checks cover Word paragraphs, tables, Unicode, attachment restore/removal, invalid files, and document-only facts in the outgoing request. Live model behavior and inactive-window clicks were not verified in this update because computer control timed out.
