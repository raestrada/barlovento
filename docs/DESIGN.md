# BARLOVENTO — Game Design Document

This document is the authoritative record of the game's design and lore. Any
agent implementing gameplay or writing content must follow it.

---

## 1. Elevator pitch

A 3D turn-based space strategy game in the spirit of *Homeworld*: real spatial
depth, naval inertia and mass — but played in turns. The player is an admiral
who positions a fleet (simultaneous phase) and then commands it in battle
(turn-based tactical phase), while also piloting and developing a personal
squad of ace heroes in the spirit of *Gundam*.

The world: a sea of dark energy — **the Éther** — is dying. A slow front of
decay called **the Calm** is spreading. Three civilizations answer with three
incompatible war goals.

## 2. Genre and references

- **Genre:** turn-based 3D space tactical strategy.
- **Spiritual ancestors:** *Homeworld* (3D RTS, spatial realism),
  *Battlestar Galactica: Deadlock* (WEGO 3D space tactics), *XCOM* (turn-based
  tactics, roster progression), *Gundam* (ace hero + fleet), *Frozen Synapse*
  (simultaneous planning), *Dune* (scarce resource drives civilization).

## 3. Core fantasy and pillars

The player must **master inertia** — every ship fights its own momentum.

1. **Newtonian vector movement** — orders set acceleration/heading; drift is
   physical, not cosmetic.
2. **Two-phase combat** — a simultaneous *Admiral* phase for positioning,
   then a turn-based *Ace* phase for the fight.
3. **Positioning that matters** — firing arcs, per-facing armor, mass and
   facing decide outcomes.
4. **Inertia as an obstacle to overcome** — mass and thrust-to-mass ratio make
   each ship feel different (capital ships plan, agile aces react).

## 4. The two phases

### Phase 1 — Admiral (simultaneous / WEGO)

The player and the opponent plan **fleet-level movement** at the same time:
course, thrust, formation, facing. Orders resolve simultaneously and play out
as a cinematic approach. This is the naval "fight for the weather gauge".

The Admiral phase **does not decide** the battle; it distributes the cards:

- initial positions, vectors and facing;
- formation cohesion;
- who gains the *initiative* (positional advantage).

### Phase 2 — Ace (turn-based, XCOM-like)

The player commands units one action at a time, fighting against inherited
momentum: burn engines to change vector, exploit drift, orient firing arcs,
target subsystems. The player's hero squad has a richer action economy than
line ships.

### Balance — 50/50

A good tactic must be able to rescue a bad strategy, and vice versa. Neither
phase may dominate: the Admiral phase grants an edge, but a skilled Ace can
overturn a positional disadvantage.

## 5. Movement and inertia model

- Everything is a vector: position, velocity, thrust.
- **Mass / thrust** ratio defines feel: capital ships (high mass) turn slowly
  and must anticipate; aces (low mass, high thrust) drift and dodge.
- The Éther provides *currents* — local field gradients that push ships and
  can be ridden (especially by the Free Tide faction).

## 6. The hero squad ("aces")

- The player fields a **squad of 2-4 named heroes**, chosen and developed over
  a campaign (XCOM-style roster with permadeath).
- Heroes are the emotional anchor and skill ceiling: distinct pilots/classes,
  XP, skills, loadout, battle scars.
- The hero unit type depends on the civilization (see §7).
- In the Ace phase the heroes are elite units; line ships receive simpler
  orders. The hero cannot win alone and cannot be everywhere — the fleet holds
  objectives and provides anti-capital fire.

## 7. The three civilizations

The three factions are three **Ways** of sailing the Star Sea, bound to a
triad: **Body / Mind / Spirit**.

| Principle | Faction | Aesthetic | Hero type | Doctrine |
| --- | --- | --- | --- | --- |
| **Body** | **The Armada of Acero** | Star Wars / BSG | Elite fighter pilots / bridge commanders | Mass and formations |
| **Mind** | **The Vinculados** | Mecha / Gundam | Mobile-suit aces | Agility and duels |
| **Spirit** | **The Free Tide** | Sankuokai / Porco Rosso steampunk | Corsair captains | Master the wind |

### 7.1 The Armada of Acero (steel)

- Capital ships + escort fighters. Heavy inertia, firepower, line-of-battle.
- **Relationship to the Éther:** consumes it as an **energy source** — the
  "spice" (Dune). Cheap, abundant dark energy underpinned their entire
  interstellar expansion.
- **The Calm's effect:** does not stop their ships, but **strangles their
  economy** — extraction fields go silent, risking regression to a
  pre-interstellar stage.
- **War goal:** dam and control the Éther; contain the Calm to protect the
  remaining fields (a domesticated, engineered sea).

### 7.2 The Vinculados (soul)

- Mobile suits + carriers. Low inertia, very high skill ceiling.
- **Relationship to the Éther:** discovered it couples to neural states — "the
  soul is made of the same stuff as the vacuum." This enables the pilot-frame
  bond (the Gundam "newtype").
- **The Calm's effect:** the field-mind coupling degrades; aces fight "cold"
  and lose their identity.
- **War goal:** complete the **Ascension** and transcend before the Calm
  covers them — escape the dying sea.

### 7.3 The Free Tide (wind)

- Wood-and-brass sailing ships with **éther sails** that ride the wind's
  currents directly. No advanced drive tech; they *feel* the sea.
- **Relationship to the Éther:** it is sacred and living; they sail it
  empirically and artisanal.
- **The Calm's effect:** no gradient means no thrust — they are **becalmed**
  and immobilized, the most existentially threatened.
- **War goal:** **re-awaken the wind** at its source and restore the sea.

## 8. The Éther (physics grounding)

- Space is a navigable sea of **dark energy** — the Éther.
- Pseudo-scientific basis: **quintessence**, the hypothesis that dark energy is
  a *dynamic scalar field* whose density can change over time (contrast with
  the constant cosmological term Λ). Real experimental analog: vacuum energy /
  the Casimir effect.
- The associated particle is the **éteron**. Factions name the field
  differently: "quintessence field" (Acero), "the Soul of the Void"
  (Vinculados), "the Wind" (Free Tide).
- Etymology note: Greek *pneuma* and Hebrew *ruah* mean both "wind" and
  "spirit/breath" — the Free Tide sails the universe's *breath*.

## 9. The Calm (the crisis)

- The vacuum is a **metastable** state; it is undergoing a **slow phase
  transition** (a slow-roll toward a lower-energy minimum), not an instant
  annihilation.
- **A single advancing front** of calm — *the Calm* — spreads across the sea.
  Where it arrives, the field's gradients vanish: the wind dies (the sailor's
  nightmare: *becalming*).
- The Calm is not uniform: it breathes with tides and leaves surviving
  currents/eddies — the map is living terrain.
- **Asymmetry of impact:** the Calm favors the faction that looks most guilty
  (Acero still navigates), which fuels suspicion and drama.

### Why it is shrinking (culpability)

The vacuum was metastable and would eventually decay. But **each faction
lowered the barrier** in its own way, and none can prove the others' guilt:

- **Acero** stressed the field with industrial harvesters and dams ("the
  Sluice"/la Compuerta).
- **Vinculados** punctured it with their Ascension experiment (tunneling
  toward the new minimum).
- **Free Tide** over-harvested the winds ("overfishing") until the fabric tore.

Result: **all three are partly responsible, none is the sole cause, nobody can
prove it** — real moral ambiguity.

### The stakes

If the Calm covers everything: the Free Tide dies, the Vinculados lose their
souls, and Acero "wins" by default — inheriting a dead, silent universe. The
three war goals (§7) are also the campaign victory conditions.

## 10. Progression and meta

- **Hero roster** with XP, skills, loadout and permadeath (the RPG loop).
- **Ship/crew persistence** so losses hurt (addresses a known weakness of
  *Deadlock*, where ships felt disposable).
- **Campaign** driven by the advancing Calm: a strategic map where the front
  applies pressure and each faction's goal is incompatible with the others.

## 11. Working title and naming

- **BARLOVENTO** (windward) — the weather-gauge position that the Admiral
  phase is about.
- Subtitle reserved: **"El Último Viento"** ("The Last Wind").

---

*This document is the design baseline. Changes must be made here first, in
English, and reflected in the implementation afterward.*
