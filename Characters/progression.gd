extends RefCounted
## Bounded linear growth. Legacy exponential values are only used while migrating saves.
const BALANCE_VERSION:=2
const MAX_LEVEL:=100
const TEST_START_LEVEL:=30
static func stats(level: int, base_health:=100.0, base_attack:=20.0, base_defense:=10.0) -> Dictionary:
	var steps:=clampi(level,1,MAX_LEVEL)-1
	return {"health":base_health+steps*5.0,"attack":base_attack+steps,"defense":base_defense+steps*.5}

static func legacy_health(level: int, base_health:=100.0) -> float:
	var capped:=clampi(level,1,MAX_LEVEL)
	var hp:=base_health+mini(capped-1,8)*10.0
	return hp*pow(1.7,clampi(capped-9,0,80))*pow(2.0,maxi(0,capped-89))
static func xp_required(level: int) -> int:
	if level>=MAX_LEVEL: return 0
	var amount:=100
	for tier in maxi(0,level/10-1): amount=ceili(amount*1.4)
	return amount
static func chapter_requirement(chapter: int) -> int:
	return 1 if chapter<=1 else mini(100,chapter*10)
static func enemy_level(index: int) -> int:
	if index>=38: return 50+(index-38)*2
	if index>=28: return 40+(index-28)*2
	if index>=18: return 30+(index-18)/3
	if index>=8: return 20+index-8
	return 1+(maxi(1,index)-1)*3
static func health_scale(level: int) -> float:
	return 1.0+(clampi(level,1,MAX_LEVEL)-1)*.025
static func enemy_health_scale(level: int, species: String="") -> float:
	# Preserve source resources; normalize oversized chapter-three boss bases.
	var adjustment: float={"naiwa_mini":700.0/1300.0,"naiwa_full":1800.0/3200.0,"penguin_mini":1100.0/2200.0,"penguin_full":5000.0/18000.0}.get(species,1.0)
	return health_scale(level)*adjustment
static func enemy_attack_scale(level: int) -> float:
	return 1.0+(clampi(level,1,MAX_LEVEL)-1)*.015
static func defense_scale(level: int) -> float:
	return 1.0+(clampi(level,1,MAX_LEVEL)-1)*.01
static func mitigate(amount: float, defense: float, _level: int) -> float:
	if amount<=0: return 0.0
	return maxf(1.0,amount*maxf(.25,100.0/(100.0+maxf(0,defense))))
static func number(value: float) -> String:
	if absf(value)>=1e16:
		var exponent:=floori(log(absf(value))/log(10.0))
		return "%.2f×10^%d"%[value/pow(10.0,exponent),exponent]
	if absf(value)>=1e12: return "%.2f万亿"%(value/1e12)
	if absf(value)>=1e8: return "%.2f亿"%(value/1e8)
	if absf(value)>=1e4: return "%.2f万"%(value/1e4)
	return "%.0f"%value
