# GBlackjack Server Owners

GBlackjack is released as source-friendly Lua so server owners can tune it for their communities.

## Common Things To Configure

- Table defaults and rules: `lua/autorun/client/cl_gblackjack.lua` and `lua/autorun/server/sv_gblackjack.lua`
- Core blackjack flow: `lua/entities/ent_blackjack_game/init.lua`
- HUD and action UI: `lua/entities/ent_blackjack_game/cl_init.lua`
- Shared rules, wager types, bot names, and bot styles: `lua/autorun/sh_gblackjack.lua`

## Notes

- Keep the `gblackjack_*` net strings unique if you fork the addon.
- Keep entity classes as `ent_blackjack_*` unless you are intentionally making a separate incompatible fork.
- DarkRP money is used automatically when the active gamemode is DarkRP.
- nMoney2 Wallet appears as a wager type when nMoney2 is installed and the player has `WalletMoney` loaded.
- Sandbox money, bot money, and health wagering are handled internally by the table.