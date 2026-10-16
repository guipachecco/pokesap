class_name Economy
extends RefCounted
## Kwanzas (Kz), a moeda do jogo. Todo ganho e gasto passa por aqui: o saldo nunca
## fica negativo, um gasto só acontece se houver saldo, e uma compra que falha não
## cobra nada (o item é entregue no mesmo passo em que o valor é descontado).
## Preços e taxas são dados: edite PRICES, SHOP e SERVICES.

## Preço de compra no Mercado da Ilha.
const PRICES := {"rede": 60, "fruta": 30, "super_fruta": 90, "mega_rede": 400}
## Ordem dos itens no mercado; alguns precisam de um serviço liberado (nível do protagonista).
const SHOP := ["rede", "fruta", "super_fruta", "mega_rede"]
const SHOP_REQUIRES := {"mega_rede": "loja_mega_rede"}
## Taxas de serviço.
const SERVICES := {"barco": 30}
## Mutação: base + por nível somado dos dois animais.
const MUTATION_BASE := 2000
const MUTATION_PER_LEVEL := 50
## Vitória contra animal selvagem: 2 Kz por nível dele.
const WILD_PER_LEVEL := 2


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out + " Kz"


static func balance() -> int:
	return Game.kwanzas


static func can_pay(amount: int) -> bool:
	return amount >= 0 and Game.kwanzas >= amount


## Recebe kwanzas (recompensas, vitórias).
static func earn(amount: int, reason := "") -> void:
	if amount <= 0:
		return
	Game.kwanzas += amount
	Game.emit_event("earn", {"n": amount, "reason": reason})


## Paga um valor. Retorna false (sem descontar nada) se não houver saldo.
static func pay(amount: int, reason := "") -> bool:
	if amount < 0 or not can_pay(amount):
		return false
	Game.kwanzas -= amount
	Game.emit_event("spend", {"n": amount, "reason": reason})
	return true


static func in_shop(item: String) -> bool:
	if not item in SHOP:
		return false
	var req: String = SHOP_REQUIRES.get(item, "")
	return req == "" or Game.unlocks.get(req, false)


static func price(item: String, qty := 1) -> int:
	return int(PRICES.get(item, 0)) * maxi(0, qty)


## Compra no mercado. Retorna "" se deu certo ou o motivo de não ter dado.
static func buy(item: String, qty: int) -> String:
	if not DB.ITEMS.has(item) or not PRICES.has(item):
		return "Este item não está à venda."
	if not in_shop(item):
		return "Este item ainda não chegou ao mercado."
	if qty <= 0:
		return "Quantidade inválida."
	var total := price(item, qty)
	if not can_pay(total):
		return "Kwanzas insuficientes: custa %s e você tem %s." % [fmt(total), fmt(Game.kwanzas)]
	if not pay(total, "compra"):
		return "O pagamento não passou."
	Game.add_item(item, qty)
	Game.emit_event("buy", {"item": item, "qty": qty, "total": total})
	return ""


static func mutation_cost(a: Creature, b: Creature) -> int:
	return MUTATION_BASE + MUTATION_PER_LEVEL * (a.level + b.level)
