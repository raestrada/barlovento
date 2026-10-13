# UI Mockups

Mockup screenshots and interface art for BARLOVENTO. Compose every screen from
the global style tokens in `000-global-style.md` plus the faction identity
blocks in `factions/`. Always include the game context block so the result
reflects BARLOVENTO, not a generic strategy game.

## Shared context block (prepend to every mockup prompt)

```
BARLOVENTO is a 3D turn-based space strategy game about naval warfare in
space, where ships have real mass, inertia and momentum, and positioning
decides battles. Space is a navigable sea of dark energy called the Éther,
visible as faint cyan currents; a slow wall of stillness called the Calm is
killing the wind. Three asymmetric civilizations: the Armada of Acero
(angular brutalist steel navy, capital ships in line-of-battle formations,
ember-orange engines), the Vinculados (sleek white humanoid mecha with
glowing magenta cores), and the Free Tide (steampunk space-galleys of treated
timber, brass, LARGE glowing cyan éther-sail membranes and banks of
éther-oars). Style: painterly sci-fi, cinematic, volumetric, cold deep-space
indigo palette, strong rim light, chiaroscuro, clear silhouettes, high
fidelity, no watermark.
```

## Admiral Phase — tactical fleet positioning (v1)

```
<SHARED CONTEXT BLOCK>

THIS IMAGE: a mockup screenshot of the ADMIRAL PHASE — the simultaneous
fleet-positioning phase, where both sides plan course, thrust, formation and
facing at once before it resolves. Show an Armada of Acero fleet: an Anvil
dreadnought and Crucible cruisers in a line-of-battle formation escorted by
Dirk frigates, in a wide tactical 3D view. The HUD must reflect THIS game's
mechanics, not a generic RTS: translucent Newtonian movement-vector arrows
(acceleration/heading, not click-to-move waypoints), dashed
formation-coherence lines linking the line of battle, a facing indicator on
each ship, a faint cyan Éther-current field flowing across the battlefield,
and a weather-gauge/initiative meter in a corner. A dark command panel with a
fleet list and a slim order bar.

RATIO: 16:9
```

## Ace Phase — turn-based tactical combat (v1)

```
<SHARED CONTEXT BLOCK>

THIS IMAGE: a mockup screenshot of the ACE PHASE — the turn-based tactical
combat phase, where you command individual ships turn by turn, fighting their
inherited momentum (inertia and drift) with action points, per-facing armor,
and firing arcs. Show a Free Tide hero galley (sealed timber hull, LARGE
glowing cyan éther-sail membranes, banks of éther-oars) dueling an angular
Acero cruiser at close range. The HUD must reflect THIS game's mechanics, not
a generic tactics UI: a visible drift/velocity vector arrow trailing the
selected ship (momentum carries over every turn), a cone-shaped firing-arc
overlay, a per-facing armor diagram on the unit card (bow armored, flanks
weaker), an action-point bar, and ability buttons.

RATIO: 16:9
```

## Hero Roster Screen (v1)

```
<SHARED CONTEXT BLOCK>

THIS IMAGE: a mockup screenshot of the HERO ROSTER screen, the RPG menu
between battles where the player manages a squad of named, persistent heroes.
Show a dark menu with a row of four hero cards, each a distinct faction
archetype with a portrait, rank insignia and stat bars (agility, armor, link):
(1) an Acero fleet officer in a uniformed greatcoat, (2) a Vinculados linked
pilot in a sleek neural suit with a magenta core glow, (3) a Free Tide goggled
corsair captain, (4) a hooded Free Tide windcaller mystic. Behind the cards, a
deep-space view with faint cyan Éther currents and the dark wall of the Calm
approaching. The game's title wordmark sits at the top.

RATIO: 16:9
```

## Asset log

| Asset | File | Ratio | Version | Date | Note |
| --- | --- | --- | --- | --- | --- |
| Admiral Phase mockup | assets/mockups/admiral-phase.png | 16:9 | v1 | 2026-10-13 | Acero line-of-battle, Newtonian vectors, coherence lines, weather-gauge HUD |
| Ace Phase mockup | assets/mockups/ace-phase.png | 16:9 | v1 | 2026-10-13 | Free Tide galley vs Acero cruiser, drift vector, firing arc, armor facings |
| Hero Roster mockup | assets/mockups/roster.png | 16:9 | v1 | 2026-10-13 | 4 hero cards across all 3 factions, title wordmark at top |
