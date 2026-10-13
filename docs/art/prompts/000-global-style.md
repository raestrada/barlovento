# 000 — Global Style Tokens

Copy this block verbatim into every image generation prompt (or reference it
and ensure the tokens are included). It enforces the shared look across all
factions and assets.

```
STYLE: painterly sci-fi concept art, cinematic lighting, volumetric depth,
not flat, not cartoon, not photorealistic.
PALETTE: cold deep-space base of near-black blue and indigo; warm ember-orange
accent for energy; cold cyan accent for the Éther.
LIGHT: strong single key light from a distant star, strong rim light, heavy
chiaroscuro, clear readable ship silhouettes.
SCALE: communicate mass; include scale reference (fighters, people, gantries)
where relevant.
ÉTHER: faint cyan/silver currents and sails, never flames.
QUALITY: high detail, clean composition, no text, no watermark, no logo.
```

## Usage

```text
<STYLE TOKENS>

<FACTION IDENTITY BLOCK from factions/<name>.md>

<ASSET DESCRIPTION>

RATIO: <16:9 | 4:3 | 1:1>
```

Asset classes and default ratios:

| Class | Ratio |
| --- | --- |
| Key art / splash / environment | 16:9 |
| Ship / mech profile (character sheet) | 1:1 or 4:3 |
| Sprite / UI icon | 1:1 |
