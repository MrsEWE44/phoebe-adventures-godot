extends RefCounted
## A paid Omo rescue owns the soundtrack until the 5-10 ending is complete.
static func omo_locked(campaign: Node) -> bool:
	if campaign.hub_chapter!=5: return false
	var index: int=campaign.active_level
	var bargain: Dictionary=campaign.states.get("46",{}).get("arena",{})
	var choice: String=str(campaign.profile.get("hell",{}).get("omo_choice",""))
	if index==46:
		return choice=="give" or (choice.is_empty() and bool(bargain.get("battle_done",false)))
	if choice!="give": return false
	if index==47: return not bool(campaign.states.get("47",{}).get("arena",{}).get("finished",false))
	if index==0:
		return bool(bargain.get("omo_music_locked",46 in campaign.completed and 47 not in campaign.completed))
	return false
