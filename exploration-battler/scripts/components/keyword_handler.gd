class_name KeywordHandler
extends Node

## Processes keyword effects and interactions.

func process_keyword(keyword: StringName, card: CardInstance, context: Dictionary) -> void:
	match keyword:
		Keywords.HASTE:
			card.has_summoning_sickness = false
		Keywords.GUARD:
			# Guard logic handled in combat resolver
			pass
		Keywords.FLYING:
			# Flying logic handled in combat resolver
			pass
		Keywords.RANGED:
			# Ranged logic handled in combat resolver
			pass
		Keywords.POISON:
			# Poison logic handled in combat resolver
			pass
		Keywords.REGENERATE:
			_process_regenerate(card)
		Keywords.LIFESTEAL:
			# Lifesteal logic handled in combat resolver
			pass
		Keywords.DEATHTOUCH:
			# Deathtouch logic handled in combat resolver
			pass
		Keywords.SHIELD:
			card.apply_keyword_effects()
		Keywords.PHASING:
			card.apply_keyword_effects()
		Keywords.FRENZY:
			# Frenzy logic handled in combat resolver
			pass
		Keywords.SOULBOUND:
			# Soulbound logic handled in combat resolver
			pass

func _process_regenerate(card: CardInstance) -> void:
	# Regenerate heals at start of turn
	var regen_amount: int = Keywords.get_default_value(Keywords.REGENERATE)
	card.heal(regen_amount)

func check_keyword_interaction(attacker: CardInstance, defender: CardInstance) -> Dictionary:
	# Returns interaction results
	var results: Dictionary = {
		"can_attack": true,
		"damage_modifier": 0
	}
	
	# Flying vs non-Flying
	if defender.has_keyword(Keywords.FLYING):
		if not attacker.has_keyword(Keywords.FLYING) and not attacker.has_keyword(Keywords.RANGED):
			results["can_attack"] = false
	
	# Guard: must attack Guard first
	# This is handled at lane level, not card level
	
	return results
