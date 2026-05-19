# DragonRuby Indie 7.2 — HTML5 audio silent

## Symptom
HTML5 publish from Indie tier yields a build with no audio at all (music
stems, SFX, anything via `args.audio[key]`). Standard tier 6.58 stubs
produce a fully-working HTML5 build from the same source.

Also reproduced with DragonRuby's shipped sample
`samples/07_advanced_audio/01_audio_mixer` published from the same
Indie 7.2 install.

## Setup
1. Install DragonRuby Indie 7.2 (May 17 2026 build) into
   `dragonruby-macos/` so `.dragonruby/stubs/html5/stub/dragonruby-wasm.wasm`
   reports `Tier: Indie`.
2. From repo root:

   ```sh
   cd dragonruby-macos
   ./dragonruby-publish --only-package
   cd ..
   ./serve_html5    # serves builds/beat2r-html5-<ver>/ on :8000
   ```

3. Open `http://localhost:8000` in a fresh incognito tab. Click to play.
4. Console shows `Tier: Indie`, no LinkError, fallback to legacy audio
   backend is reached cleanly (native C ext intentionally not loaded for
   this repro). Tracks are registered:

   ```
   [TrackPlayer] legacy registered track_drums path=sounds/music/drums.wav
   entry={:input=>"sounds/music/drums.wav", :gain=>1.0, :looping=>true,
   :paused=>false}
   ```

   …yet nothing audible plays.

## Workaround
Replace `.dragonruby/stubs/html5/` with the equivalent files from a
Standard tier 6.58 stub set. Audio returns immediately, no source
changes required. (Loses C-extension capability in HTML5 publish.)

## Stub manifest difference
Standard 6.58 stubs ship:
  dragonruby-wasm.wasm, dragonruby-wasm.js, dragonruby-wasm.worker.js,
  dragonruby-serviceworker.js, dragonruby-html5-loader.js

Indie 7.2 stubs ship: same set minus `dragonruby-wasm.worker.js`.

Hybrid attempts (.dragonruby/stubs/html5/stub/):
- Indie wasm.wasm + Indie wasm.js + Standard worker.js → still silent
- Indie wasm.wasm + Standard wasm.js + Standard worker.js →
  `LinkError: Import "_emscripten_thread_cleanup": function import
  requires a callable` (Indie wasm imports threading symbols Standard
  glue doesn't provide; confirms Indie wasm uses pthreads)
- Standard wasm.wasm + Indie wasm.js →
  `LinkError: Import "abort": function import requires a callable`
  (tier-locked ABI)

Reading: Indie wasm.wasm is built with pthread / SharedArrayBuffer, but
the Indie zip ships no worker.js shim, and the Indie wasm.js + main-
thread setup doesn't initialize the audio output for that pthread
config. Possibly the audio sink relies on a worker that never starts.

## Sample-only repro (no beater code involved)
```sh
cp dragonruby-macos/mygame/metadata/icon.png \
   ~/Downloads/dragonruby-macos/samples/07_advanced_audio/01_audio_mixer/metadata/
cd ~/Downloads/dragonruby-macos
./dragonruby-publish --only-package samples/07_advanced_audio/01_audio_mixer/
cd builds/audiomixer-html5-1.0 && python3 -m http.server 8002
```
Open `http://localhost:8002` — UI is fully interactive, but spawning any
sound is silent.
