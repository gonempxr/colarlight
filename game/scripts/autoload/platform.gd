extends Node
## Where the game runs and what that site offers: rewarded ads, purchases,
## a player account with cloud saves. Registered as the Platform autoload.
##
## Without a provider (itch.io, GitHub Pages, desktop) nothing here is
## available and the UI hides every ad and purchase button, so there are
## no buttons that do nothing.

signal purchase_done(product: String, ok: bool)

var provider := "none"


func ads_available() -> bool:
	return false


## Shows a rewarded ad; `done(true)` runs only when it was watched to the end.
func show_rewarded(done: Callable) -> void:
	done.call(false)


func payments_available() -> bool:
	return false


## Local price text for a product ("" when unknown).
func price(_product: String) -> String:
	return ""


func purchase(product: String) -> void:
	purchase_done.emit(product, false)
