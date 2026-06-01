# Alert sound files

Drop audio loops here to use real recordings instead of synthesized tones. The
packaging script copies this folder into `Nudgebar.app/Contents/Resources/Sounds`,
and a sound is registered in `AlertSoundCatalog` with `file("Display Name", "filename.ext")`.

## Format

- Supported: `.m4a`, `.mp3`, `.wav`, `.aiff`, `.caf`
- Prefer a steady, seamless loop (30s-2min) so the loop point is unnoticeable.
- Short one-shot tones are padded with ~0.6s of silence so they loop as a gentle
  recurring "ding ... gap ... ding".

## Licensing (important for a shippable app)

Use only files you can legally bundle and redistribute:

- **CC0 / public domain** - no attribution, commercial OK (preferred).
- **Mixkit Free License** - commercial OK, no attribution; may NOT be redistributed
  as standalone files or be the primary product. Bundled inside this app = allowed.
- **CC-BY** - allowed, but requires a credit; add it to the About screen.
- Avoid **CC-BY-NC** (no commercial use) and **CC-BY-SA** (share-alike).

## Bundled files

### Wikimedia Commons - public domain / CC0 (no attribution)

| File          | Sound                        | License       | Source                                       |
| ------------- | ---------------------------- | ------------- | -------------------------------------------- |
| rain.m4a      | Rainfall                     | Public domain | File:Rain.ogg                                |
| ocean.m4a     | Lake/ocean waves (first 60s) | Public domain | File:Waves.ogg                               |
| birds.m4a     | Woodland birdsong            | Public domain | File:Birdsong_mild_sunny_day.ogg             |
| fireplace.m4a | Fireplace crackling          | Public domain | File:Dry_grass_burning_in_open_fireplace.ogg |
| clock.m4a     | Ticking clock                | Public domain | File:Clock_ticking.ogg                       |
| airplane.m4a  | Airplane cabin hum           | Public domain | File:Sound_in_air_plane_1.ogg                |
| gong.m4a      | Meditation gong              | CC0           | File:Meditation_Gong.ogg                     |

### Mixkit - Mixkit Free License (no attribution, padded with silence to loop)

| File            | Sound                    | Source (mixkit.co SFX id) |
| --------------- | ------------------------ | ------------------------- |
| bell.m4a        | Bell notification        | 933                       |
| happy_bells.m4a | Happy bells notification | 937                       |
| positive.m4a    | Positive notification    | 951                       |
| magic_ring.m4a  | Magic notification ring  | 2344                      |
| guitar.m4a      | Guitar notification      | 2320                      |
| marimba.m4a     | Magic marimba            | 2820                      |
