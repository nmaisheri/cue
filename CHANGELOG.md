# Changelog

## 1.3.0

- Add Read browser and ⌘⇧B with a browser-window chooser, capture preview, retake, and explicit Answer screenshot action.
- Send the selected image with instructions, résumé, and recent conversation through the existing streaming answer request.
- Retain one in-memory snapshot for follow-ups with title, capture time, and removal controls; clearing the conversation also removes it.
- Capture only the selected window, cap the image long edge at 2,048 pixels, and keep all screenshots off disk.
- Pause automatic answer scheduling while selecting a screenshot, and preserve the question when API-key setup is needed.
- Add image-payload, browser-filtering, JPEG, bounds, and text-only compatibility checks.

## 1.2.2

- Persist extracted attachment text and filename across launches.
- Show successful import, attachment status, and an expandable extracted-text preview.
- Use explicit Word/RTF document formats and reject unsupported or unreadable input.
- Encourage relevant facts from both attachments and instructions; preserve explicit factual corrections.
- Accept first-click activation events and disable hit testing on decorative borders.
- Add regression checks for Word paragraphs, tables, Unicode, persistence, removal, invalid files, and attachment facts in answer payloads.

## 1.2.1

- Remove blocking Keychain reads from startup and add explicit saved-key unlocking.
- Run Keychain operations away from the main UI thread.
- Show speech and recording permission stages and time out unanswered speech authorization.
- Clean up duplicate app builds and temporary staging folders.

## Earlier development

- Build a lightweight SwiftUI menu bar app with a floating horizontal layout.
- Add adjustable translucent backdrop, global show/hide shortcut, and separate question/answer panes.
- Capture incoming system audio and transcribe through Apple Speech, with recognition segment rotation.
- Stream answer suggestions using instructions, document background, and recent conversation.
- Add typed questions, follow-up history, automatic/manual triggering, cancellation, and error handling.
- Add selectable answer models, a fast-answer preset, and measured time to first answer text.
- Package the macOS app, source, build instructions, and troubleshooting guide.

This repository starts with the current complete snapshot. Earlier development was not committed to Git, so earlier revisions are summarized here rather than represented as historical commits.
