class_name RpgDefs
extends RefCounted

# =============================================================================
# RPG DATA DEFINITIONS FOR BARLOVENTO: EL ÚLTIMO VIENTO
# Pilot skill trees, shipyard upgrade tiers, and asymmetric faction subsystems.
# =============================================================================

# --- ACE PILOT SKILL TREE DEFINITION ---
class SkillNode:
	var id: String
	var name: String
	var branch: int # 0: Tactical Doctrine, 1: Combat Mastery, 2: Helmsmanship
	var tier: int # 1, 2, 3
	var cost_sp: int = 1
	var icon_name: String
	var summary: String
	var requires_id: String

	func _init(p_id: String, p_name: String, p_branch: int, p_tier: int, p_summary: String, p_req: String = "") -> void:
		id = p_id
		name = p_name
		branch = p_branch
		tier = p_tier
		summary = p_summary
		requires_id = p_req

# --- SHIPYARD UPGRADE TRACK DEFINITION ---
class UpgradeTier:
	var tier: int
	var name: String
	var cost_eteron: int
	var hp_mult: float
	var armor_mult: float
	var dmg_mult: float
	var thrust_mult: float
	var speed_mult: float

	func _init(p_tier: int, p_name: String, p_cost: int, p_hp: float, p_armor: float, p_dmg: float, p_thrust: float, p_speed: float) -> void:
		tier = p_tier
		name = p_name
		cost_eteron = p_cost
		hp_mult = p_hp
		armor_mult = p_armor
		dmg_mult = p_dmg
		thrust_mult = p_thrust
		speed_mult = p_speed

# --- FACTION ASYMMETRIC SUBSYSTEM DEFINITION ---
class SubsystemDef:
	var id: String
	var name: String
	var faction: String
	var cost_eteron: int
	var summary: String
	var stat_tag: String

	func _init(p_id: String, p_name: String, p_faction: String, p_cost: int, p_summary: String, p_tag: String) -> void:
		id = p_id
		name = p_name
		faction = p_faction
		cost_eteron = p_cost
		summary = p_summary
		stat_tag = p_tag

# =============================================================================
# STATIC REGISTRIES
# =============================================================================

static var _skills: Array[SkillNode] = []
static var _skills_by_id: Dictionary = {}
static var _shipyard_tiers: Dictionary = {} # category -> Array[UpgradeTier]
static var _subsystems: Dictionary = {} # faction -> Array[SubsystemDef]

static func get_all_skills() -> Array[SkillNode]:
	_ensure_init()
	return _skills

static func get_skill(id: String) -> SkillNode:
	_ensure_init()
	return _skills_by_id.get(id, null)

static func get_shipyard_tiers(category: String) -> Array[UpgradeTier]:
	_ensure_init()
	return _shipyard_tiers.get(category, [])

static func get_subsystems_for_faction(faction: String) -> Array:
	_ensure_init()
	return _subsystems.get(faction, [])

static func _ensure_init() -> void:
	if not _skills.is_empty():
		return

	# -------------------------------------------------------------------------
	# 1. ACE PILOT SKILL TREES (Branches: 0=Doctrine, 1=Combat, 2=Helmsmanship)
	# -------------------------------------------------------------------------
	# Branch 0: Tactical Doctrine (Command, Fleet AP, Synergy)
	_add_skill(SkillNode.new("doc_battle_rhythm", "Battle Rhythm", 0, 1, "+1 Maximum Action Point (AP) in Ace Phase for this pilot's squad."))
	_add_skill(SkillNode.new("doc_target_designation", "Target Designation", 0, 2, "Attacking a target marks it, granting all nearby fleet allies +15% accuracy for 1 turn.", "doc_battle_rhythm"))
	_add_skill(SkillNode.new("doc_tactical_overdrive", "Tactical Overdrive", 0, 3, "Reduces the turn cooldown of all active Ace Phase maneuvers by 1 turn.", "doc_target_designation"))

	# Branch 1: Combat Mastery (Firepower, Broadside Penetration, Critical Harmonics)
	_add_skill(SkillNode.new("cbt_armor_piercing", "Kinetic / Resonance Piercing", 1, 1, "+15% direct damage penetration against heavily reinforced directional bow armor."))
	_add_skill(SkillNode.new("cbt_range_calibrator", "Optics & Lance Focusing", 1, 2, "+12% maximum weapon firing range for all broadsides and lances.", "cbt_armor_piercing"))
	_add_skill(SkillNode.new("cbt_alpha_strike", "Alpha Salvo Overdrive", 1, 3, "First attack made each round deals +25% bonus critical kinetic/beam damage.", "cbt_range_calibrator"))

	# Branch 2: Helmsmanship (Newtonian Maneuverability, Inertia Mastery)
	_add_skill(SkillNode.new("hlm_inertial_tuning", "Inertial Dampener Tuning", 2, 1, "+15% turn rate and -10% unwanted vector drift penalty while turning at speed."))
	_add_skill(SkillNode.new("hlm_retro_thrusters", "Emergency Retros", 2, 2, "+25% brake thrust, allowing rapid full-stops within a single combat turn.", "hlm_inertial_tuning"))
	_add_skill(SkillNode.new("hlm_slipstream_surf", "Éther Slipstream Surfing", 2, 3, "Moving directly windward grants +1 free Action Point every turn.", "hlm_retro_thrusters"))

	# -------------------------------------------------------------------------
	# 2. FLEET SHIPYARD UPGRADE TIERS (Categories: armor, weapons, engines)
	# -------------------------------------------------------------------------
	# Armor Plating: Bow, Port, Stbd, Stern protection
	var armor_tracks: Array[UpgradeTier] = [
		UpgradeTier.new(0, "Standard Bulkheads", 0, 1.0, 1.0, 1.0, 1.0, 1.0),
		UpgradeTier.new(1, "Reinforced Composite I", 350, 1.10, 1.15, 1.0, 1.0, 1.0),
		UpgradeTier.new(2, "Heavy Ceramic-Steel II", 700, 1.20, 1.30, 1.0, 1.0, 1.0),
		UpgradeTier.new(3, "Adamantine Citadels III", 1200, 1.35, 1.50, 1.0, 1.0, 1.0),
	]
	_shipyard_tiers["armor"] = armor_tracks

	# Weapon Batteries: Kinetic Broadside, Pulse Cannons, Beam Lances
	var weapon_tracks: Array[UpgradeTier] = [
		UpgradeTier.new(0, "Standard Ordnance", 0, 1.0, 1.0, 1.0, 1.0, 1.0),
		UpgradeTier.new(1, "Overcharged Capacitors I", 400, 1.0, 1.0, 1.12, 1.0, 1.0),
		UpgradeTier.new(2, "High-Velocity Barrels II", 800, 1.0, 1.0, 1.25, 1.0, 1.0),
		UpgradeTier.new(3, "Apex Thermal Disruptors III", 1400, 1.0, 1.0, 1.40, 1.0, 1.0),
	]
	_shipyard_tiers["weapons"] = weapon_tracks

	# Éther Thrusters: Vector Maneuverability, Acceleration, Max Speed
	var engine_tracks: Array[UpgradeTier] = [
		UpgradeTier.new(0, "Standard Vector Coils", 0, 1.0, 1.0, 1.0, 1.0, 1.0),
		UpgradeTier.new(1, "Tuned Éther Manifolds I", 350, 1.0, 1.0, 1.0, 1.15, 1.10),
		UpgradeTier.new(2, "Superheated Reaction Jets II", 750, 1.0, 1.0, 1.0, 1.30, 1.20),
		UpgradeTier.new(3, "Gravimetric Drive Rings III", 1300, 1.0, 1.0, 1.0, 1.48, 1.32),
	]
	_shipyard_tiers["engines"] = engine_tracks

	# -------------------------------------------------------------------------
	# 3. FACTION ASYMMETRIC SUBSYSTEM MODULES
	# -------------------------------------------------------------------------
	# Acero: Pure Hard-Science Naval Steel
	_subsystems["acero"] = [
		SubsystemDef.new("acero_ram_prow", "Reinforced Ram Prow", "acero", 500, "Bow armor absorbs 100% of collision impact damage and crushes smaller hulls.", "ram_prow"),
		SubsystemDef.new("acero_torpedo_magazine", "Autoloader Torpedo Battery", "acero", 850, "Increases forward missile salvo damage by +30% and reduces reload time.", "torpedo_overdrive"),
		SubsystemDef.new("acero_vulcan_dampeners", "Vulcan Inertia Anchors", "acero", 1100, "Grants +50% braking thrust when executing full reverse stop orders.", "dampener_anchors"),
	]

	# Vinculados: Soul / Resonance Gundam Frame Technology
	_subsystems["vinculados"] = [
		SubsystemDef.new("vinc_funnel_rack", "Fin Funnel Remote Array", "vinculados", 600, "Deploys telepathic beam funnels that harass enemy ships at extreme range.", "funnel_array"),
		SubsystemDef.new("vinc_soul_shield", "Soul Core Phase Barrier", "vinculados", 900, "Energy shield capacity increased by +40% with instant shield recovery when windward.", "soul_barrier"),
		SubsystemDef.new("vinc_beam_saber_oc", "Psycho-Frame Overclock", "vinculados", 1250, "Mobile Suit Ace units gain +2 starting AP and deal +35% melee/lance critical damage.", "psycho_overclock"),
	]

	# Free Tide (Marea Libre): Wind Corsairs & Éther Galleons
	_subsystems["marea_libre"] = [
		SubsystemDef.new("marea_ether_sails", "Resonant Solar Windcatchers", "marea_libre", 550, "Harnesses the dying Éther wind to boost top speed by +25% in crosswind sectors.", "wind_sails"),
		SubsystemDef.new("marea_grappling_harpoon", "Boarding Harpoon Rig", "marea_libre", 800, "Fires magnetic grapples that snare fleeing capital ships and drain their AP.", "grapple_harpoon"),
		SubsystemDef.new("marea_carronade_battery", "Double-Shot Carronades", "marea_libre", 1150, "Close-range broadsides fire double grape shot, shredding unarmored sterns.", "carronade_grape"),
	]

static func _add_skill(node: SkillNode) -> void:
	_skills.append(node)
	_skills_by_id[node.id] = node
