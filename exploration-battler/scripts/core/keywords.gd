class_name Keywords
extends RefCounted

## Keyword constants and helper functions for card keywords.

# All 12 keywords from GDD Section 5.4
const HASTE: StringName = &"Haste"
const GUARD: StringName = &"Guard"
const FLYING: StringName = &"Flying"
const RANGED: StringName = &"Ranged"
const POISON: StringName = &"Poison"
const REGENERATE: StringName = &"Regenerate"
const LIFESTEAL: StringName = &"Lifesteal"
const DEATHTOUCH: StringName = &"Deathtouch"
const SHIELD: StringName = &"Shield"
const PHASING: StringName = &"Phasing"
const FRENZY: StringName = &"Frenzy"
const SOULBOUND: StringName = &"Soulbound"

# Keyword descriptions for UI
static func get_description(keyword: StringName) -> String:
	match keyword:
		HASTE:
			return "Can attack the turn it's played"
		GUARD:
			return "Enemies in this lane must attack this card first"
		FLYING:
			return "Only damaged by Flying or Ranged units"
		RANGED:
			return "Can attack any lane, not just directly across"
		POISON:
			return "Deals damage to attacker when damaged"
		REGENERATE:
			return "Heals at start of your turn"
		LIFESTEAL:
			return "Damage dealt heals your life total"
		DEATHTOUCH:
			return "Any damage this deals to a creature kills it"
		SHIELD:
			return "Negates the first damage instance, then breaks"
		PHASING:
			return "Can't be targeted the turn it's played"
		FRENZY:
			return "Attacks twice per combat phase"
		SOULBOUND:
			return "When this dies, return it to your hand (once per battle)"
		_:
			return ""

# Check if keyword requires a value (like Poison X)
static func requires_value(keyword: StringName) -> bool:
	return keyword == POISON or keyword == REGENERATE

# Get default value for keyword if applicable
static func get_default_value(keyword: StringName) -> int:
	match keyword:
		POISON:
			return 1
		REGENERATE:
			return 1
		_:
			return 0
