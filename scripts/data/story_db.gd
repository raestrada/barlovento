class_name StoryDB
extends RefCounted

static var _data: Dictionary = {}

static func get_story_data(stage_id: String) -> Dictionary:
	if _data.is_empty():
		_init_database()
	return _data.get(stage_id, _get_fallback_data(stage_id))

static func _init_database() -> void:
	_data["acero_stage_1"] = {
		"title": "ACT I // STAGE 01 [TUTORIAL]: DEFENSE OF SLUICE STATION WELL-09",
		"faction": "acero",
		"act": 1,
		"backdrop": "res://assets/briefings/acero_act1.png",
		"intro_summary": "WAR LOG // SECTOR ANVIL: Free Tide corsairs have slipped through the outer basalt reef to sever Sluice Station Well-09. Without this ether conduit, the orbital foundries will stall. Admiral Vane leads the line-of-battle to anchor the perimeter.",
		"intro_dialogue": [
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "All hands, sound general quarters. Corsair raiders are bearing down on Well-09. We form the anvil that shatters their sails."},
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Kinetic batteries armed and loaded, Admiral. Those void-pirates think our armor is too sluggish for these tight narrows."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Let them come. Remember your doctrine: angle your prow armor into their fire, lock the weather-gauge, and rake them with broadsides."},
		],
		"outro_summary": "AFTERMATH: Sluice Station Well-09 secured. The corsair vanguard has been broken, but reconnaissance relays indicate an encroaching resonance signature deeper in the crystalline drift.",
		"outro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Target ships dismantled or scattered into the reef, Admiral! Well-09 reports fuel pressure normalizing across all transfer conduits."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Good work, Korr. But this raid was merely a diversion. Long-range sensors have picked up the Vinculados Choir mobilizing near the Resonance Spire. Helm, prepare next vector!"},
		]
	}

	_data["acero_stage_2"] = {
		"title": "ACT I // STAGE 02: AMBUSH AT THE RESONANCE SPIRE",
		"faction": "acero",
		"act": 1,
		"backdrop": "res://assets/briefings/acero_act1.png",
		"intro_summary": "WAR LOG // SECTOR RESONANCE: A strike wing of Vinculados mobile suits has appeared around the ancient harmonic crystals. Their bio-resonance cores are siphoning energy directly from the Star Sea's arterial stream.",
		"intro_dialogue": [
			{"speaker": "Lt. Drake", "role": "Escort Corvette // Vanguard-03", "portrait": "res://assets/heroes/ace_drake.png", "side": "right", "text": "Admiral! High-mobility humanoid contacts dropping from the crystal crowns! They are riding the crosswind like birds of prey!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Steady, Drake. Mobile suits have high agility but fragile frames. Tighten escorts, keep our point-defense flak overlapping, and do not let them bypass our bows."},
		],
		"outro_summary": "AFTERMATH: The Vinculados reconnaissance echelon was neutralized before they could synchronize the spire. Telemetry recovered from their wreckages reveals a disturbing phenomenon: the Calm wavefront is accelerating.",
		"outro_dialogue": [
			{"speaker": "Lt. Drake", "role": "Escort Corvette // Vanguard-03", "portrait": "res://assets/heroes/ace_drake.png", "side": "right", "text": "All enemy mobile suits down! Their neural traces have flatlined, Admiral. But look at our sensors... the outer stars are dimming."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "The Calm is moving faster than High Command predicted. If the wind dies, humanity freezes in the dark. We must reach the Threshold Bastion immediately."},
		]
	}

	_data["acero_stage_3"] = {
		"title": "ACT I // STAGE 03: BASTION OF THE CALM THRESHOLD",
		"faction": "acero",
		"act": 1,
		"backdrop": "res://assets/briefings/acero_act1.png",
		"intro_summary": "WAR LOG // THE CALM THRESHOLD: At the edge of the fading sea, a coalition of corsairs and rogue pilots are attempting to flee through the final operable gateway, threatening to tear down the imperial containment barrier.",
		"intro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Look at the edge of the sector, Admiral... complete void silence. Nothing moves in the Calm. The corsairs are in a blind panic."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Panic makes men reckless. If they blow open the containment gates, the Calm seeps directly into our industrial core. Line of battle, lock shields and hold the line!"},
		],
		"outro_summary": "AFTERMATH: Threshold Bastion secured. The imperial line held firm against overwhelming odds. High Command has authorized deployment of the Heavy Siege Fleet to fortify the Obsidian Sluice.",
		"outro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Threshold perimeter stabilized. We held the gate, sir! Steel truly endures where flesh falters."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "We bought time, but Act I is only the overture. The Siege of the Obsidian Sluice begins now. All ships, transition to Act II operational sectors!"},
		]
	}

	_data["acero_stage_4"] = {
		"title": "ACT I // STAGE 04: THE CRUCIBLE OF FIRE",
		"faction": "acero",
		"act": 1,
		"backdrop": "res://assets/briefings/acero_act1.png",
		"intro_summary": "WAR LOG // IRON GATE TERTIUS: Corsair fast-raiders are attempting to dynamite the canal sluice. Heavy torpedo frigates have been attached to Vane's squadron to purge the raiders.",
		"intro_dialogue": [
			{"speaker": "Lt. Silas", "role": "Torpedo Lead // CNS Halberd", "portrait": "res://assets/heroes/ace_drake.png", "side": "right", "text": "Halberd torpedo banks primed, Admiral. Fast skiffs are weaving through the mineral gantries."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Lead their vectors, Silas. Do not waste ordnance on ghosts. Hammer them when they commit to their torpedo runs."},
		],
		"outro_summary": "AFTERMATH: Iron Gate Tertius remains in imperial hands. The canal locks are sealed tight.",
		"outro_dialogue": [
			{"speaker": "Lt. Silas", "role": "Torpedo Lead // CNS Halberd", "portrait": "res://assets/heroes/ace_drake.png", "side": "right", "text": "Direct hits recorded across all raider hulls. The canal gate is locked down."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Excellent marksmanship. Re-arm and prepare for heavy fleet actions in the basalt trenches."},
		]
	}

	_data["acero_stage_5"] = {
		"title": "ACT II // STAGE 05: SIEGE OF THE OBSIDIAN SLUICE",
		"faction": "acero",
		"act": 2,
		"backdrop": "res://assets/briefings/acero_act2.png",
		"intro_summary": "WAR LOG // OBSIDIAN SLUICE: The Grand Fleet has arrived at the colossal volcanic trenches. Admiral Tarek anchors the line aboard the heavy siege monitor CNS Crucible.",
		"intro_dialogue": [
			{"speaker": "Adm. Tarek", "role": "Siege Master // CNS Crucible", "portrait": "res://assets/heroes/ace_tarek.png", "side": "right", "text": "Vane! Good to have your dreadnought beside us. My heavy plasma mortar needs a solid screening line while we crack the corsair redoubts."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "You will have your screen, Tarek. Form echelon formation. Any enemy vessel entering the trench dies under our converging batteries."},
		],
		"outro_summary": "AFTERMATH: The Corsair redoubt collapsed under sustained bombardment from the Crucible. The basalt trench has been pacified.",
		"outro_dialogue": [
			{"speaker": "Adm. Tarek", "role": "Siege Master // CNS Crucible", "portrait": "res://assets/heroes/ace_tarek.png", "side": "right", "text": "Redoubt pulverized! Nothing withstands thirty-two inches of high-density molten iron."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Advance through the breach. The iron wall marches forward."},
		]
	}

	_data["acero_stage_6"] = {
		"title": "ACT II // STAGE 06: BATTLE OF THE FOUNDRY BASTION",
		"faction": "acero",
		"act": 2,
		"backdrop": "res://assets/briefings/acero_act2.png",
		"intro_summary": "WAR LOG // FOUNDRY VULCAN: Rebel corvettes have infiltrated the smelting platforms, threatening the master blast furnaces.",
		"intro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Molten slag everywhere, Admiral. Sensor readings are blinded by the heat plume!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Rely on optical sights and vector acoustics. When you see their engine flares through the smoke, unleash full broadsides."},
		],
		"outro_summary": "AFTERMATH: Foundry Vulcan is secure. Production of heavy dreadnought plating resumes unhindered.",
		"outro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "The rebels are routed, sir. Smelters are burning at maximum output once more."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Well fought. Our heavy armor has proven itself against fire and steel."},
		]
	}

	_data["acero_stage_7"] = {
		"title": "ACT II // STAGE 07: CLASH IN THE CALM TRENCH",
		"faction": "acero",
		"act": 2,
		"backdrop": "res://assets/briefings/acero_act2.png",
		"intro_summary": "WAR LOG // DEAD CALM TRENCH: The fleet navigates a narrow corridor where the ether current drops to zero. Kinetic momentum and internal reactor fuel must substitute for wind-lift.",
		"intro_dialogue": [
			{"speaker": "Adm. Tarek", "role": "Siege Master // CNS Crucible", "portrait": "res://assets/heroes/ace_tarek.png", "side": "right", "text": "Engines are choking on the dead ether, Vane. Without the wind to ride, our mass works against us."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Newtonian physics never sleep, Tarek. Burns on heading, coast on momentum, and do not waste propellant on unnecessary yaw maneuvers."},
		],
		"outro_summary": "AFTERMATH: The dead trench cleared. The imperial squadron demonstrated the superiority of hard Newtonian ballistics in zero-ether space.",
		"outro_dialogue": [
			{"speaker": "Adm. Tarek", "role": "Siege Master // CNS Crucible", "portrait": "res://assets/heroes/ace_tarek.png", "side": "right", "text": "Enemy squadron shattered. We punched straight through the dead zone on pure engine power."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "This proves our doctrine: the Star Sea may die, but steel will carve its own path."},
		]
	}

	_data["acero_stage_8"] = {
		"title": "ACT II // STAGE 08: THE FORGE WORLD BLOCKADE",
		"faction": "acero",
		"act": 2,
		"backdrop": "res://assets/briefings/acero_act2.png",
		"intro_summary": "WAR LOG // ANVIL HIGH ORBIT: A massive corsair armada and mercenary mecha wings have surrounded Forge World Anvil in a desperate bid to dismantle its industrial spine.",
		"intro_dialogue": [
			{"speaker": "Cmdr. Vance", "role": "Fleet Carrier Lead // CNS Forge-01", "portrait": "res://assets/heroes/ace_vane.png", "side": "right", "text": "Arsenal Carrier Forge-01 in position, Admiral. All strike wings ready for defensive patrol."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Deploy point-defense flak envelopes. Break their assault waves against our hulls. Anvil will not fall today!"},
		],
		"outro_summary": "AFTERMATH: The blockade is broken. Wreckage of hundreds of corsair and rogue craft rain down upon the planetary defense shields.",
		"outro_dialogue": [
			{"speaker": "Cmdr. Vance", "role": "Fleet Carrier Lead // CNS Forge-01", "portrait": "res://assets/heroes/ace_vane.png", "side": "right", "text": "Enemy lines disintegrating across all orbital sectors, sir! The planet is safe."},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Act II is won. Now we look toward the apocalyptic abyss. Act III: The Calm Singularity awaits."},
		]
	}

	_data["acero_stage_9"] = {
		"title": "ACT III // STAGE 09: BREAKING THE SINGULARITY GATES",
		"faction": "acero",
		"act": 3,
		"backdrop": "res://assets/briefings/acero_act3.png",
		"intro_summary": "WAR LOG // THE EVENT HORIZON: The fleet reaches the outer boundary of the Calm Singularity, where space-time itself begins to crystallize under entropy.",
		"intro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "The singularity is pulling on our bulkheads, Admiral! Gyroscopes are straining!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Max thrust to forward stabilizers! Aim quad spinal railguns at the gate pylons. Fire!"},
		],
		"outro_summary": "AFTERMATH: The Singularity Gate shattered under railgun fire, opening a stabilized breach into the heart of the anomaly.",
		"outro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Breach achieved! Pylons collapsing into the gravity vortex!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Form combat box. We proceed into the dying core of the Star Sea."},
		]
	}

	_data["acero_stage_10"] = {
		"title": "ACT III // STAGE 10: CLASH OF TITANS",
		"faction": "acero",
		"act": 3,
		"backdrop": "res://assets/briefings/acero_act3.png",
		"intro_summary": "WAR LOG // THE TITAN'S REACH: The Vinculados have awakened their Colossal Mobile Armor 'Seraph-Prime'. It stands between Acero and the Singularity Dam.",
		"intro_dialogue": [
			{"speaker": "Grand Marshall Kurtz", "role": "Supreme Flagship // CNS Imperator", "portrait": "res://assets/heroes/ace_vane.png", "side": "right", "text": "Vane! The Colossus Imperator is on station. That divine mechanical beast thinks it can transcend entropy. Show them the weight of iron!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Synchronize spinal batteries with the Imperator! All ships, concentrate fire on its resonance core!"},
		],
		"outro_summary": "AFTERMATH: Seraph-Prime's resonance wings shattered under the concentrated fire of the supreme juggernaut line.",
		"outro_dialogue": [
			{"speaker": "Grand Marshall Kurtz", "role": "Supreme Flagship // CNS Imperator", "portrait": "res://assets/heroes/ace_vane.png", "side": "right", "text": "Target core destabilized! The colossus has fallen back!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Steady our lines. The ultimate test remains: The Calm Singularity itself."},
		]
	}

	_data["acero_stage_11"] = {
		"title": "ACT III // STAGE 11: THE CALM SINGULARITY",
		"faction": "acero",
		"act": 3,
		"backdrop": "res://assets/briefings/acero_act3.png",
		"intro_summary": "WAR LOG // SINGULARITY THRESHOLD: The grand containment wall must be anchored directly into the vortex. The entire void roars as the wind dies.",
		"intro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "Void decay spreading across our hull plating, sir! The cold... it's draining our batteries!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Overcharge furnace coils! As long as our furnaces burn, the cold has no dominion here! Lock anchors!"},
		],
		"outro_summary": "AFTERMATH: Anchors locked into the bedrock of the void. The dam pylons hold.",
		"outro_dialogue": [
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "The pylons are holding! The vortex is being throttled back!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "One final battle to seal the dam forever. Prepare for Stage 12: The Iron Dam."},
		]
	}

	_data["acero_stage_12"] = {
		"title": "ACT III // STAGE 12: THE IRON DAM // THE FINAL REDOUBT",
		"faction": "acero",
		"act": 3,
		"backdrop": "res://assets/briefings/acero_act3.png",
		"intro_summary": "WAR LOG // THE IRON DAM: The ultimate battle for the preservation of humanity's cradle. The Armada forms an unbroken line of steel across the dying sea.",
		"intro_dialogue": [
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Brothers and sisters of Acero. Beyond us lies the total stillness of cosmic extinction. Behind us lies every furnace, every home, every child of humanity. We do not step back."},
			{"speaker": "Capt. Korr", "role": "Battlecruiser Lead // CNS Hammer", "portrait": "res://assets/heroes/ace_korr.png", "side": "right", "text": "We do not step back, Admiral! For the Armada! For the Iron Dam!"},
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "All ships... FULL SALVO! STEEL ENDURES!"},
		],
		"outro_summary": "VICTORY COMPLETE: The Iron Dam has been sealed! The Calm is held at bay by an insurmountable bastion of gunmetal and nuclear fire. The Armada has saved civilization.",
		"outro_dialogue": [
			{"speaker": "Adm. Vane", "role": "Fleet Admiral // CNS Iron Bastion", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "The gates are locked. The ether flows through our regulated sluices. Humanity will survive the dark. Well done, armada. Stand down from battle stations."},
		]
	}

	_data["vinculados_stage_1"] = {
		"title": "ACT I // STAGE 01 [TUTORIAL]: DEFENSE OF SANCTUARY SPIRE PSALM-4",
		"faction": "vinculados",
		"act": 1,
		"backdrop": "res://assets/briefings/vinculados_act1.png",
		"intro_summary": "CHOIR RECORD // SANCTUARY PSALM-4: Imperial corsair pickets are attempting to dismantle the harmonic resonance crystal spires. Ace Kaelen-7 launches the Eidolon Mobile Suit Platoon to protect the sacred harmonics.",
		"intro_dialogue": [
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Conductor Seraph, neural link synchronized. The choir sings clearly today. Intercepting imperial raiders."},
			{"speaker": "Conductor Seraph-2", "role": "Carrier Ark // Sanktuario Albor", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "Kaelen, keep your vernier thrusters tuned to the wind. Remember: your mobile suit is an extension of your soul. Strike with grace."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Understood. Phase verniers engaged. Let us show them the dance of the Star Sea."},
		],
		"outro_summary": "AFTERMATH: Sanctuary Spire Psalm-4 secured. The harmonic choir echoes without distortion.",
		"outro_dialogue": [
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "All hostiles dispersed, Conductor. The spire's song is pure once more."},
			{"speaker": "Conductor Seraph-2", "role": "Carrier Ark // Sanktuario Albor", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "The choir acknowledges your harmony, Kaelen. Prepare to descend into the Crystal Chasm."},
		]
	}

	_data["vinculados_stage_2"] = {
		"title": "ACT I // STAGE 02: DIVE INTO THE CRYSTAL CHASM",
		"faction": "vinculados",
		"act": 1,
		"backdrop": "res://assets/briefings/vinculados_act2.png",
		"intro_summary": "CHOIR RECORD // BASALT CRYSTAL CHASM: Clumsy Acero capital ships are navigating the narrow canyon floor below. The Vinculados execute a high-angle dive from the upper celestial ledge.",
		"intro_dialogue": [
			{"speaker": "Ace Mirei-4", "role": "High-Speed Interceptor // Anima-01", "portrait": "res://assets/heroes/ace_mirei.png", "side": "right", "text": "Look at those heavy iron dreadnoughts down in the chasm, Kaelen! They cannot even tilt their guns upward!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Maintain vertical discipline, Mirei. Dive with the ether current and rake their unarmored upper decks with beam lances!"},
		],
		"outro_summary": "AFTERMATH: The dive bomber strike crippled the imperial patrol with surgical precision.",
		"outro_dialogue": [
			{"speaker": "Ace Mirei-4", "role": "High-Speed Interceptor // Anima-01", "portrait": "res://assets/heroes/ace_mirei.png", "side": "right", "text": "Target ships neutralized! That was like dancing through rain!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Form up on the Ark. The Genesis Ring is awakening."},
		]
	}

	_data["vinculados_stage_3"] = {
		"title": "ACT I // STAGE 03: THE GENESIS RING // TRANSCENDENCE",
		"faction": "vinculados",
		"act": 1,
		"backdrop": "res://assets/briefings/vinculados_act1.png",
		"intro_summary": "CHOIR RECORD // THE GENESIS RING: The ancient megastructure that aligns the Star Sea's harmonic frequencies has begun to resonate. Heavy Nous assault frames deploy to protect the tuning sequence.",
		"intro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "Nous heavy choir cannons online! If those corsairs touch the tuning rings, I will atomize their timber!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Screen the ring's focal emitter, Orin. The gateway must remain intact for our people."},
		],
		"outro_summary": "AFTERMATH: The Genesis Ring was successfully tuned. A bridge of pure violet resonance now reaches into the deeper sectors.",
		"outro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "Focal emitter stable at ninety-nine percent. The pathway is open."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The choir prepares to journey into Act II. All wings, return to carrier decks."},
		]
	}

	_data["vinculados_stage_4"] = {
		"title": "ACT I // STAGE 04: THE ECHO ARCHIPELAGO",
		"faction": "vinculados",
		"act": 1,
		"backdrop": "res://assets/briefings/vinculados_act1.png",
		"intro_summary": "CHOIR RECORD // ECHO DRIFT: Sensor-distorting crystalline islets create ghost signatures across the battlefield.",
		"intro_dialogue": [
			{"speaker": "Ace Mirei-4", "role": "High-Speed Interceptor // Anima-01", "portrait": "res://assets/heroes/ace_mirei.png", "side": "right", "text": "Our radar is reflecting dozens of false targets! How do we know which one is real?"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Close your optical screens and feel the bio-resonance. A machine's ghost has no soul."},
		],
		"outro_summary": "AFTERMATH: The illusions dissipated as the genuine hostiles were dismantled.",
		"outro_dialogue": [
			{"speaker": "Ace Mirei-4", "role": "High-Speed Interceptor // Anima-01", "portrait": "res://assets/heroes/ace_mirei.png", "side": "right", "text": "You were right, Kaelen! Their cold iron couldn't mask their intent."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Faith in the resonance guides our lances."},
		]
	}

	_data["vinculados_stage_5"] = {
		"title": "ACT II // STAGE 05: AWAKENING OF SERAPH-PRIME",
		"faction": "vinculados",
		"act": 2,
		"backdrop": "res://assets/ships/vinculados/mobile_armor_colossus.png",
		"intro_summary": "CHOIR RECORD // FRACTURE RIFT: The legendary Colossal Mobile Armor Seraph-Prime begins its harmonic wake-up cycle.",
		"intro_dialogue": [
			{"speaker": "Ascendant Mind Core", "role": "Autonomous Divine Reactor // Seraph-Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "SOUL REACTOR CRITICAL... HARMONIC FUNNELS ACTIVE. ALL THREATS MARKED FOR TRANSCENDENCE."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The Colossus awakens! Screen its binder wings until its field barriers reach full saturation!"},
		],
		"outro_summary": "AFTERMATH: Seraph-Prime's funnel corona eradicated the approaching vanguard.",
		"outro_dialogue": [
			{"speaker": "Ascendant Mind Core", "role": "Autonomous Divine Reactor // Seraph-Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "HARMONIC CONVERGENCE ACHIEVED. TRANSCENDENCE PROTOCOLS EXPANDING."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The divine machine stands with us."},
		]
	}

	_data["vinculados_stage_6"] = {
		"title": "ACT II // STAGE 06: SYMPHONY OF THE 5-VOICE CHOIR",
		"faction": "vinculados",
		"act": 2,
		"backdrop": "res://assets/briefings/vinculados_act2.png",
		"intro_summary": "CHOIR RECORD // CHORAL FORMATION: Five specialized mobile suit wings synchronize their bio-resonance frequencies to create a localized beam vortex.",
		"intro_dialogue": [
			{"speaker": "Conductor Trio", "role": "Choral Swarm Lead // Chorus Echelon", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "Five voices, one frequency. Synchronize beam convergence and dissolve their cruiser screens!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Strike together as one note across the void!"},
		],
		"outro_summary": "AFTERMATH: The enemy cruiser screens dissolved under the converging choir beams.",
		"outro_dialogue": [
			{"speaker": "Conductor Trio", "role": "Choral Swarm Lead // Chorus Echelon", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "A flawless symphony. The enemy was dismantled without breaking rhythm."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Beautifully executed, pilots."},
		]
	}

	_data["vinculados_stage_7"] = {
		"title": "ACT II // STAGE 07: THE CALM ABYSS TRENCH",
		"faction": "vinculados",
		"act": 2,
		"backdrop": "res://assets/briefings/vinculados_act2.png",
		"intro_summary": "CHOIR RECORD // DEAD ZONE: Flying through a sector where the ether wind has already died. Only internal soul cores keep the mobile suits mobile.",
		"intro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "The wind is completely dead here... my verniers are sluggish!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Draw power from your internal soul reactor, Orin! We carry our own wind inside our hearts!"},
		],
		"outro_summary": "AFTERMATH: Against the dead chill of the Calm, the Vinculados proved their independence from ambient ether.",
		"outro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "The internal soul core held! We conquered the dead zone!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "We are ready for the final stages."},
		]
	}

	_data["vinculados_stage_8"] = {
		"title": "ACT II // STAGE 08: PARLEY AT THE ASTROLABE",
		"faction": "vinculados",
		"act": 2,
		"backdrop": "res://assets/briefings/vinculados_act2.png",
		"intro_summary": "CHOIR RECORD // NEUTRAL ASTROLABE: Joint defensive pact with Corsair free captains against an imperial purge fleet.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Free Tide Corsair // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "Good to fight by your wings, mechas! Screen our void-galleons and we'll shatter their iron with broadsides!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Agreed, Captain Solano. Freedom and transcendence fly under the same banner today."},
		],
		"outro_summary": "AFTERMATH: The imperial purge fleet was driven off by the combined might of corsair broadsides and mecha lances.",
		"outro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Free Tide Corsair // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "Ha! A splendid dance, Kaelen! May the wind ever fill your wings!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Fair winds, Captain. The Transcendence Gate awaits our choir in Act III."},
		]
	}

	_data["vinculados_stage_9"] = {
		"title": "ACT III // STAGE 09: SHATTERING THE SLUICE DAM",
		"faction": "vinculados",
		"act": 3,
		"backdrop": "res://assets/ships/vinculados/mobile_armor_colossus.png",
		"intro_summary": "CHOIR RECORD // IMPERIAL SLUICE DAM: The massive imperial dam choking the natural flow of the Star Sea must be breached.",
		"intro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "Nous heavy choir cannons charged! Fire upon the dam gate hinges! Free the tide of the Star Sea!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Shatter their dams! The ether must flow free!"},
		],
		"outro_summary": "AFTERMATH: The dam hinges fractured. A torrent of luminous cyan ether burst across the dead sectors.",
		"outro_dialogue": [
			{"speaker": "Ace Orin-9", "role": "Heavy Assault Lead // Nous-04", "portrait": "res://assets/heroes/ace_orin.png", "side": "right", "text": "The dam is broken! Look at the river rushing through!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Ride the current into the Singularity!"},
		]
	}

	_data["vinculados_stage_10"] = {
		"title": "ACT III // STAGE 10: TITAN RECKONING // EIDOLON VS IMPERATOR",
		"faction": "vinculados",
		"act": 3,
		"backdrop": "res://assets/ships/vinculados/mobile_armor_colossus.png",
		"intro_summary": "CHOIR RECORD // SINGULARITY REACH: Acero's supreme flagship Imperator attempts to seal off the Transcendence Gate.",
		"intro_dialogue": [
			{"speaker": "Ascendant Mind Core", "role": "Divine War-Machine // Seraph-Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "COLOSSUS ENGAGED. AUTONOMOUS FUNNELS FORMING CORONA FORMATION."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Fly beside Seraph-Prime! Cut through their escort screens!"},
		],
		"outro_summary": "AFTERMATH: The Imperator was forced to withdraw its vanguard.",
		"outro_dialogue": [
			{"speaker": "Ascendant Mind Core", "role": "Divine War-Machine // Seraph-Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "CORONA COMPLETE. PATHWAY CLEARED."},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The gate shines before us."},
		]
	}

	_data["vinculados_stage_11"] = {
		"title": "ACT III // STAGE 11: THE CALM SINGULARITY",
		"faction": "vinculados",
		"act": 3,
		"backdrop": "res://assets/ships/vinculados/mobile_armor_colossus.png",
		"intro_summary": "CHOIR RECORD // TOTAL ENTROPY: The edge of reality where the Calm threatens to dissolve both flesh and steel.",
		"intro_dialogue": [
			{"speaker": "Conductor Seraph-2", "role": "Carrier Ark // Sanktuario Albor", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "The Calm is collapsing the sector! Channel all residual resonance into the Transcendence Gate!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Choir of the Vinculados, sing with everything you have!"},
		],
		"outro_summary": "AFTERMATH: The gateway stabilized as millions of harmonic waves converged into a crystalline path.",
		"outro_dialogue": [
			{"speaker": "Conductor Seraph-2", "role": "Carrier Ark // Sanktuario Albor", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "right", "text": "The gate is holding! We stand at the threshold of the Great Ascension!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Stage 12: The Final Hymn."},
		]
	}

	_data["vinculados_stage_12"] = {
		"title": "ACT III // STAGE 12: SYMPHONY OF THE STAR SEA // THE ASCENSION",
		"faction": "vinculados",
		"act": 3,
		"backdrop": "res://assets/ships/vinculados/mobile_armor_colossus.png",
		"intro_summary": "CHOIR RECORD // THE ASCENSION: All choirs united. The Vinculados cross beyond the dying Star Sea into higher dimensional resonance.",
		"intro_dialogue": [
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The gateway opens! Sing, pilots of the Choir! We cross beyond the dying wind into eternity!"},
			{"speaker": "Ace Mirei-4", "role": "High-Speed Interceptor // Anima-01", "portrait": "res://assets/heroes/ace_mirei.png", "side": "right", "text": "Our wings are bathed in light! We are flying beyond the Calm!"},
			{"speaker": "Ace Kaelen-7", "role": "Choir Flight Lead // Eidolon Prime", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "Farewell to the sea of stars. We are eternal."},
		],
		"outro_summary": "VICTORY COMPLETE: The Great Ascension is achieved! The Vinculados have transcended the mortal realm, leaving behind an eternal hymn that echoes across the cosmos.",
		"outro_dialogue": [
			{"speaker": "Conductor Seraph-2", "role": "Carrier Ark // Sanktuario Albor", "portrait": "res://assets/heroes/ace_kaelen.png", "side": "left", "text": "The Choir has reached the other side. Peace descends upon the soul."},
		]
	}

	_data["marea_stage_1"] = {
		"title": "ACT I // STAGE 01 [TUTORIAL]: THE BASALT NARROWS",
		"faction": "marea_libre",
		"act": 1,
		"backdrop": "res://assets/briefings/marea_act1.png",
		"intro_summary": "CORSAIR LOG // BASALT NARROWS: Imperial blockades are choking the haven of the Free Tide. Captain Solano commands the void-galleon Viento Rojo to catch the ether rapids and break the blockade.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Unfurl the quantum sails, sea dogs! Catch the rapids of El R\u00edo del Viento, claim the Weather-Gauge [BARLOVENTO], and sweep their flanks with full broadsides!"},
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "The wind is howling at twenty knots along the basalt cliffs, Captain! Imperial gunboats can't maneuver in this turbulence!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Then we cross their T and send them down into the basalt deeps! All hands to the gun decks!"},
		],
		"outro_summary": "AFTERMATH: The imperial blockade was shattered. The Basalt Narrows belong to the Free Tide once more.",
		"outro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "Lead gunboat sunk, escorts scattering like frightened gulls! The narrows are open, Captain!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Ha-ha! A fine morning on the Star Sea! Pour an extra ration of rum for the gun crews and set course for Foundry Vulcan-3!"},
		]
	}

	_data["marea_stage_2"] = {
		"title": "ACT I // STAGE 02: RAID ON FOUNDRY VULCAN-3",
		"faction": "marea_libre",
		"act": 1,
		"backdrop": "res://assets/briefings/marea_act2.png",
		"intro_summary": "CORSAIR LOG // INDUSTRIAL FOUNDRY: Imperial ore bastions are ripe for pillaging. Strike under the cover of gantry steam to seize fuel reserves.",
		"intro_dialogue": [
			{"speaker": "Capt. Moreau", "role": "Brigantine // Brisa Negra", "portrait": "res://assets/heroes/ace_moreau.png", "side": "right", "text": "Smelter exhaust is thick enough to hide our masts, Solano. When we clear the refinery gantry... FULL BROADSIDE AMBUSH!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Strike fast, take their ether fuel canisters, and vanish before their garrison wakes up!"},
		],
		"outro_summary": "AFTERMATH: Fuel silos raided and imperial escorts crippled. Holds are overflowing with refined ether.",
		"outro_dialogue": [
			{"speaker": "Capt. Moreau", "role": "Brigantine // Brisa Negra", "portrait": "res://assets/heroes/ace_moreau.png", "side": "right", "text": "Fuel holds full to the gunwales! Their dockyard towers are burning behind us!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Now for the real challenge: surfing the Maelstrom of Barlovento!"},
		]
	}

	_data["marea_stage_3"] = {
		"title": "ACT I // STAGE 03: THE MAELSTROM OF BARLOVENTO",
		"faction": "marea_libre",
		"act": 1,
		"backdrop": "res://assets/briefings/marea_act3.png",
		"intro_summary": "CORSAIR LOG // THE GREAT VORTEX: The Grand Sol Corona creates a swirling tempest of quantum wind. Only true sailors dare ride the vortex.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "The wind howls like the birth of creation! All hands to the sails! Ride the Maelstrom and break their dreadnoughts!"},
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Three-deck batteries manned! Catch the crest of the tidal surge and rake them stem to stern!"},
		],
		"outro_summary": "AFTERMATH: Surfed through the crest of the storm, leaving broken imperial iron spinning into the corona.",
		"outro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Their dreadnoughts lost their rudder in the crosscurrents! We took the weather gauge!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "No one sails the wind like the Free Tide! Act I is in our pocket!"},
		]
	}

	_data["marea_stage_4"] = {
		"title": "ACT I // STAGE 04: THE FREE TRADER CONVOY",
		"faction": "marea_libre",
		"act": 1,
		"backdrop": "res://assets/briefings/marea_act1.png",
		"intro_summary": "CORSAIR LOG // MERCHANT CROSSING: Imperial pickets are hunting merchant void-clippers carrying refugees from the Calm.",
		"intro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "Merchant clippers under fire! Form a screening wall before their shields collapse!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Deploy La Saeta to torpedo their lead corvettes! Protect the convoy!"},
		],
		"outro_summary": "AFTERMATH: Convoy escorted safely past the imperial cordons.",
		"outro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "All merchant clippers accounted for. They are cheering our flag from their rigging!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "That's what the Free Tide stands for: liberty on the high sea!"},
		]
	}

	_data["marea_stage_5"] = {
		"title": "ACT II // STAGE 05: PRIZE OF THE 'SOBERANO'",
		"faction": "marea_libre",
		"act": 2,
		"backdrop": "res://assets/briefings/marea_act2.png",
		"intro_summary": "CORSAIR LOG // DERELICT GRAVEYARD: The legendary abandoned imperial mega-galleon Soberano floats inside an asteroid cluster.",
		"intro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "There she sits\u2014the grandest hull in the fleet! Grapple her decks and clear out the automated security!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Boarding party away! That magnificent monster will fly our skull-and-wind banner!"},
		],
		"outro_summary": "AFTERMATH: The Soberano has been claimed! Its 6-deck guns are re-firing for freedom.",
		"outro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "She's ours, Captain! Power online, quantum sails unfurling like celestial wings!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Now let the iron admirals come and try to take her back!"},
		]
	}

	_data["marea_stage_6"] = {
		"title": "ACT II // STAGE 06: THE DEAD REEF AMBUSH",
		"faction": "marea_libre",
		"act": 2,
		"backdrop": "res://assets/briefings/marea_act2.png",
		"intro_summary": "CORSAIR LOG // BASALT REEF: Dense mineral dust blinds sensors. Quiet running ambush on an imperial ore convoy.",
		"intro_dialogue": [
			{"speaker": "Capt. Moreau", "role": "Brigantine // Brisa Negra", "portrait": "res://assets/heroes/ace_moreau.png", "side": "right", "text": "Quiet running, lanterns out. When the convoy passes between the two needles... FIRE ALL BROADSIDES!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Let them hear the thunder of free sailors!"},
		],
		"outro_summary": "AFTERMATH: Convoy captured without losing a single corsair vessel.",
		"outro_dialogue": [
			{"speaker": "Capt. Moreau", "role": "Brigantine // Brisa Negra", "portrait": "res://assets/heroes/ace_moreau.png", "side": "right", "text": "Clean sweep! They surrendered their flags before the second salvo."},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Splendid ambush, Moreau. On to Fort Almirante!"},
		]
	}

	_data["marea_stage_7"] = {
		"title": "ACT II // STAGE 07: SIEGE OF FORT ALMIRANTE",
		"faction": "marea_libre",
		"act": 2,
		"backdrop": "res://assets/briefings/marea_act2.png",
		"intro_summary": "CORSAIR LOG // FORTRESS CITADEL: The coastal bastion guarding the passage to the deep ocean must be battered down.",
		"intro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Bring El Trueno into firing position! Arc plasma mortar shells over the outer bastion walls!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Cover the bombards! Keep their patrol frigates away while our mortars crack the citadel!"},
		],
		"outro_summary": "AFTERMATH: Fort Almirante's guns silenced. The passage to the deep star sea is open.",
		"outro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Citadel banner struck! The fortress has surrendered!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "The sea is opening up before our bows."},
		]
	}

	_data["marea_stage_8"] = {
		"title": "ACT II // STAGE 08: THE GHOST FLOTILLA",
		"faction": "marea_libre",
		"act": 2,
		"backdrop": "res://assets/briefings/marea_act2.png",
		"intro_summary": "CORSAIR LOG // LUMINOUS NEBULA: Ancient derelicts and rogue drones drifting in the shimmering fog.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Eyes sharp! Rogue drones are hiding among the wrecks! Stay in formation and surf the glowing currents!"},
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "Harpoons ready to snag salvage as we fight!"},
		],
		"outro_summary": "AFTERMATH: Drones cleared, ancient star maps recovered from the flagship derelict.",
		"outro_dialogue": [
			{"speaker": "Quartermaster Vael", "role": "Raider Lead // La Descarada", "portrait": "res://assets/heroes/ace_vael.png", "side": "right", "text": "We found the charts to the Triple Confluence, Captain!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "The wind calls us to Act III! Prepare to sail into the storm!"},
		]
	}

	_data["marea_stage_9"] = {
		"title": "ACT III // STAGE 09: THE TRIPLE CONFLUENCE",
		"faction": "marea_libre",
		"act": 3,
		"backdrop": "res://assets/briefings/marea_act3.png",
		"intro_summary": "CORSAIR LOG // RAGING RAPIDS: Three massive ether rivers colliding at terminal velocity. Maximum speed and sail trim required.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Maximum speed! Trim the sails for thirty knots! Out-sail their battle line and rake them from stem to stern!"},
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Riding the triple wave! Fire all batteries as we cross their wake!"},
		],
		"outro_summary": "AFTERMATH: The imperial line was outmaneuvered and shattered in the confluence rapids.",
		"outro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Their formation split in half! They couldn't match our speed!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Speed and liberty! Onward to the Iron Citadel!"},
		]
	}

	_data["marea_stage_10"] = {
		"title": "ACT III // STAGE 10: BREAKING THE IRON CITADEL",
		"faction": "marea_libre",
		"act": 3,
		"backdrop": "res://assets/briefings/marea_act3.png",
		"intro_summary": "CORSAIR LOG // IMPERIAL NAVAL BASE: Assault on Acero's forward citadel. Crack the gantry gates and burn their repair docks.",
		"intro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "All corsair squadrons converge! Crack their gantry gates and burn their drydocks!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Batter down their defenses with plasma chain-shot! Free the captive sailors!"},
		],
		"outro_summary": "AFTERMATH: The Iron Citadel has fallen. Thousands of corsairs freed from imperial brigs.",
		"outro_dialogue": [
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "right", "text": "Drydocks demolished and captives freed! The entire corsair brotherhood is cheering!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Now we unite the Grand Corsair Armada for the Eye of Chaos!"},
		]
	}

	_data["marea_stage_11"] = {
		"title": "ACT III // STAGE 11: EYE OF CHAOS",
		"faction": "marea_libre",
		"act": 3,
		"backdrop": "res://assets/briefings/marea_act3.png",
		"intro_summary": "CORSAIR LOG // MAELSTROM APEX: The greatest storm in creation colliding directly with the advancing Calm wavefront.",
		"intro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "The storm is tearing reality apart! But a true sailor dances with the whirlwind! TO GLORY!"},
			{"speaker": "Barbanegra", "role": "Soberano-Class Mega-Galleon", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "Let the guns of the Soberano roar! We fight for the soul of the Star Sea!"},
		],
		"outro_summary": "AFTERMATH: The calm wavefront was pushed back by the sheer kinetic gale of the Maelstrom.",
		"outro_dialogue": [
			{"speaker": "Barbanegra", "role": "Soberano-Class Mega-Galleon", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "The gale has turned! The weather gauge is in our hands!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Stage 12 awaits! The Liberation of the Sovereign Ocean!"},
		]
	}

	_data["marea_stage_12"] = {
		"title": "ACT III // STAGE 12: THE SOVEREIGN OCEAN // THE FINAL GALE",
		"faction": "marea_libre",
		"act": 3,
		"backdrop": "res://assets/briefings/marea_act3.png",
		"intro_summary": "CORSAIR LOG // THE SOVEREIGN OCEAN: The entire Star Sea reclaimed for freedom. The Grand Corsair Armada claims the ultimate weather gauge [BARLOVENTO].",
		"intro_dialogue": [
			{"speaker": "Barbanegra", "role": "Supreme Void Corsair // Soberano del Mar", "portrait": "res://assets/heroes/ace_solano.png", "side": "left", "text": "Unfurl the royal sails of the Soberano! As long as the wind blows across the void, NO EMPEROR, NO CHATTERING AI, NO MAN OWNS THE SEA!"},
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "All ships, full broadsides! Ride the eternal gale! LIBERTY ON THE STAR SEA!"},
			{"speaker": "Commodore Marina", "role": "Heavy Frigate // El Gavil\u00e1n", "portrait": "res://assets/heroes/ace_marina.png", "side": "left", "text": "BARLOVENTO! FIRE!"},
		],
		"outro_summary": "VICTORY COMPLETE: The Star Sea is liberated! The wind howls free through every canal and rift. The Free Tide reigns sovereign across the infinite ocean.",
		"outro_dialogue": [
			{"speaker": "Capt. Solano", "role": "Corsair Flagship // Viento Rojo", "portrait": "res://assets/heroes/ace_solano.png", "side": "right", "text": "The sea is ours, brothers and sisters! As long as stars shine in the black, we sail free!"},
		]
	}

static func _get_fallback_data(stage_id: String) -> Dictionary:
	return {
		"title": stage_id.to_upper(),
		"faction": "acero",
		"act": 1,
		"backdrop": "res://assets/briefings/acero_act1.png",
		"intro_summary": "WAR LOG: Operational tactical deployment in progress.",
		"intro_dialogue": [
			{"speaker": "Commander", "role": "Squadron Lead", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "All hands, battle stations. Tactical link established."}
		],
		"outro_summary": "AFTERMATH: Tactical engagement resolved successfully.",
		"outro_dialogue": [
			{"speaker": "Commander", "role": "Squadron Lead", "portrait": "res://assets/heroes/ace_vane.png", "side": "left", "text": "Hostiles cleared. Prepare for next operational briefing."}
		]
	}
