+++
title = "Screen Recording"
description = "Quick screen recordings with wf-recorder, and when to reach for OBS instead."
weight = 36
template = "docs/page.html"

[extra]
lead = "One keybind records a region of the screen to a file. For anything longer or more involved, use OBS."
toc = true
+++

## Quick recordings

Press `Super+Shift+R`, drag a region, and recording starts. Press
`Super+Shift+R` again to stop. A notification confirms the start and then
shows where the file was saved.

**System, Screen Recording** does the same from the menu and also offers
**Record Screen**, which records the whole focused monitor.

Files are written to your Videos folder as
`recording-YYYYMMDD-HHMMSS.mp4`. Recordings have no audio. This is
[`wf-recorder`](https://github.com/ammen99/wf-recorder), a small tool
meant for short clips such as a bug report or a quick demo.

## When to use OBS

OBS Studio is in the **Creative** [software profile](../../installer/software-profiles/)
and is the better tool when you need audio, a microphone, a webcam,
several scenes, window capture, or streaming. It takes a few minutes of
setup (a PipeWire screen capture source, then your audio inputs), after
which it is more capable than the keybind.
