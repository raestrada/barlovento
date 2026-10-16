# Cinematic Prompts & Sequence Registry

> **Purpose:** Versioned record of cinematic video sequences, cutscenes, and opening prologues.  
> **Source of Truth for:** `assets/video/intro.ogv`

---

## 1. Opening Cinematic Prologue — *"El Último Viento"*

- **Output:** `assets/video/intro.ogv`
- **Render Engine:** Blender 4.2 LTS (EEVEE Next 3D Engine + VSE Compositor) via `tools/render_intro_3d.py`
- **Format:** 1280x720 @ 24fps, Ogg Theora video, Vorbis audio (Native Godot 4 `VideoStreamPlayer` compatible)
- **Soundtrack:** Gustav Holst — *The Planets*, Op. 32 (Movement II: "Venus, the Bringer of Peace"), performed by the U.S. Air Force Heritage Band (Public Domain / CC-PD) + deep ambient space rumble (`assets/audio/ambient_hum.ogg`).
- **Duration:** 720 frames (30.0 seconds)
- **3D Assets & Models:**
  - *Armada of Acero:* Procedural wedge-bow dreadnought with tiered command citadel, twin cylindrical nacelles with volumetric ember-orange exhaust plumes, and turret batteries.
  - *The Vinculados:* Procedural articulated ceramic humanoid frame with radiant magenta/violet soul core, cyan visor, and dual resonance blade wings.
  - *The Free Tide:* Procedural curved timber-hull void galleon with brass bowsprit, lantern cabin viewports, and towering translucent cyan quantum sail membranes.
  - *The Calm:* Procedural light-absorbing dead vacuum wavefront sweeping over drifting derelict ships.
  - *Title Crest:* Canonical engraved steel [`assets/brand/logo.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/brand/logo.png) illuminated with cold cyan rim-light.

### 1.1 Storyboard Structure & Visual Directives

1. **Shot 01: The Star Sea (*El Mar Estelar*) [Frames 1–120]**
   - *Visual:* Deep cosmic blue void with faint cyan quintessence currents drifting across starlight.
   - *Key Art:* [`assets/environments/star_sea_skybox.jpg`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/environments/star_sea_skybox.jpg)
   - *Text:* *"PROLOGUE: In the beginning, the void was not empty. It was the Star Sea... an ocean of dark energy called the Éther."*

2. **Shot 02: The Armada of Acero (Body) [Frames 110–230]**
   - *Visual:* Angular brutalist dreadnought emerging from vacuum shadow, blazing ember-orange fusion thrusters.
   - *Key Art:* [`assets/ships/acero/dreadnought_concept.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/ships/acero/dreadnought_concept.png)
   - *Text:* *"THE ARMADA OF ACERO: An empire of steel that burned the wind as fuel, forging colossal battle lines to tame the deep."*

3. **Shot 03: The Vinculados (Mind) [Frames 220–340]**
   - *Visual:* Sleek white ceramic humanoid frame with cold magenta/violet neural resonance aura.
   - *Key Art:* [`assets/ships/vinculados/suit_concept.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/ships/vinculados/suit_concept.png)
   - *Text:* *"THE VINCULADOS: Mystic pilots bonded to the vacuum by neural resonance, singing in harmony with the soul of the void."*

4. **Shot 04: The Free Tide (*La Marea Libre*, Spirit) [Frames 330–450]**
   - *Visual:* Vacuum-sealed ironwood and brass galleon riding cyan quantum currents on gossamer radial sails.
   - *Key Art:* [`assets/ships/marea-libre/galleon_concept.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/ships/marea-libre/galleon_concept.png)
   - *Text:* *"THE FREE TIDE: Nomad corsairs who unfurled quantum sails on wooden hulls, riding the living breath of creation."*

5. **Shot 05: The Cataclysm — The Calm (*La Calma*) [Frames 440–560]**
   - *Visual:* Desaturation, freezing shadows creeping over the Star Sea, dead currents, cold silence.
   - *Key Art:* [`assets/environments/space_backdrop.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/environments/space_backdrop.png)
   - *Text:* *"THE CALM: Then came the silence. A creeping frost of dead vacuum. Where the Calm arrives, the wind dies... fleets are becalmed."*

6. **Shot 06: The Conflict — Battle for the Weather Gauge [Frames 550–670]**
   - *Visual:* Massive fleet collision, laser fire, drifting broadsides, heroic aces diving into the fray.
   - *Key Art:* [`assets/splash/cover.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/splash/cover.png)
   - *Text:* *"THE LAST CURRENT: Three armadas clash for the surviving currents. In the dying sea... to drift is to die."*

7. **Shot 07: Monumental Title Reveal [Frames 660–800]**
   - *Visual:* Deep black void. Canonical engraved steel wordmark with cyan Éther rim-glow.
   - *Key Art:* Canonical logo [`assets/brand/logo.png`](file:///w:/home/rodrigoestrada/workspace/github.com/raestrada/barlovento/assets/brand/logo.png)
   - *Text:* *"BARLOVENTO: EL ÚLTIMO VIENTO — Take the helm... and fight for the weather gauge."*

---

## 2. Asset Log

| Asset | File | Resolution | Version | Date | Note |
|---|---|---|---|---|---|
| Opening Prologue Video | `assets/video/intro.ogv` | 1920x1080 (24fps) | v3 | 2026-10-15 | Full HD 1080p (EEVEE Next + VSE). Features procedural sculpted rocky asteroids with crater displacement, 8-ship fleet combat with 12 dynamic lasers and 4 explosion shockwaves, DSP synthesized naval railgun/plasma sound design, Hollywood trailer BRAAAM title drop at frame 642, and canonical BARLOVENTO logo overlay finale. |
