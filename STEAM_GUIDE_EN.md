<!-- Steam 指南稿源（英文）：MOD 的完整說明以本指南為準，簡介只放摘要。格式、版面與同步方式見 pz-family-docs/release.md「完整說明：Steam 指南」 -->
<!-- 標題：📖 Minidoracat Dismantle Any Car MP Mod Guide: Dismantling, Multiplayer and Sandbox Options -->
<!-- 摘要：Full guide for the mod that lets you dismantle any vehicle with a propane torch: how to do it, the tools you need, what happens to items inside, what a multiplayer server checks, sandbox options, known limits and FAQ. -->
=== 🚀 Quick Start
[b]繁體中文版：[/b][url=XXXX]Minidoracat Dismantle Any Car MP 完整說明[/url]

The mod (Steam Workshop):
https://steamcommunity.com/sharedfiles/filedetails/?id=XXXX
[list]
[*] [b]Game version[/b]: Build 42.22.2 or newer. No other mods required.
[*] [b]Modes[/b]: single player, multiplayer and dedicated servers. In multiplayer the server must enable this mod.
[*] [b]Add/remove mid-save[/b]: safe either way. After removal, intact vehicles go back to vanilla and cannot be dismantled.
[/list]
[olist]
[*] [b]Get the tools[/b]: a welding mask and a propane torch with at least 10 uses left.
[*] [b]Right-click[/b]: right-click a vehicle and choose "Dismantle Vehicle".
[*] [b]Confirm[/b]: if items are still inside, you are asked first.
[*] [b]Done[/b]: the vehicle is gone for good and the materials drop where it stood.
[/olist]
=== 🧰 Dismantling a Vehicle
{{img:01-menu-en.jpg}}
[list]
[*] [b]Which vehicles[/b]: all of them. Intact cars and trailers show "Dismantle Vehicle". Burnt and smashed vehicles show the vanilla "Dismantle Car Wreck".
[*] [b]Tools[/b]: the same as dismantling a wreck in vanilla. One welding mask and 10 uses of a propane torch. The tooltip lists what you are missing.
[*] [b]Cost[/b]: 10 uses of the propane torch each time.
[*] [b]Time[/b]: the same as dismantling a wreck in vanilla. Higher Welding is faster.
[*] [b]Materials[/b]: the same metal materials and Welding XP as a vanilla wreck. Higher Welding gives more.
[/list]
=== 📦 When Items Are Still Inside
{{img:02-confirm-en.jpg}}
[list]
[*] [b]Confirmation[/b]: if the trunk, glove box or seats still hold items, the mod shows how many first.
[*] [b]After you confirm[/b]: the items are destroyed with the vehicle. They do not drop on the ground, so take out what you want to keep.
[*] [b]Installed parts[/b]: tires, battery, seats and other parts still on the vehicle are destroyed too. Uninstall them first if you want them.
[/list]
=== 🌐 Multiplayer Servers
[list]
[*] [b]Server re-check[/b]: removing the vehicle and giving materials both happen on the server. It checks that the vehicle still exists, that you are next to it, that nobody is inside and that no animals are in the trailer.
[*] [b]If a check fails[/b]: the vehicle stays and no materials drop.
[*] [b]Vehicle protection mods[/b]: this mod reuses the vanilla dismantle action. With Minidoracat Vehicle Manager, a claimed vehicle can only be dismantled by its owner or an admin.
[*] [b]Dismantle log[/b]: for every dismantled vehicle the server writes one line to the MinidoracatDismantle log file in the Logs folder: account, vehicle type, vehicle id, coordinates, number of parts and number of items inside.
[/list]
=== ⚙️ Sandbox Options and Defaults
[table]
[tr][th]Option[/th][th]Default[/th][th]Description[/th][/tr]
[tr][td]Dismantle Loot Multiplier[/td][td]1.0[/td][td]Multiplies the materials you get from dismantling a vehicle or a wreck, from 0 to 10. 1.0 is vanilla. In multiplayer the server applies it.[/td][/tr]
[/table]
=== ⚠️ Known Limits
[list]
[*] [b]Stay close[/b]: you can move while dismantling, but the action stops if you go more than about 6 tiles away.
[*] [b]Passengers and animals[/b]: a vehicle with someone inside, or a trailer with animals, cannot be dismantled. Get them out first.
[*] [b]No vehicle protection[/b]: this mod does not care who owns a vehicle. To protect your vehicles, use a vehicle protection mod.
[*] [b]Other dismantling mods[/b]: do not enable other mods that change the dismantle action at the same time. The menu shows duplicates and the checks may stop working.
[/list]
=== ❓ FAQ
[h3]There is no "Dismantle Vehicle" option?[/h3]
[list]
[*] Make sure the mod is enabled. In multiplayer the server must enable it too.
[*] Burnt and smashed vehicles show the vanilla "Dismantle Car Wreck" instead.
[/list]
[h3]The option is red?[/h3]
[list]
[*] Hover over it. The tooltip lists what is missing in red: welding mask, torch uses, someone inside, or animals in the trailer.
[/list]
[h3]The action stops halfway?[/h3]
[list]
[*] It stops if the torch leaves your hand, you move too far away, or someone enters the vehicle.
[/list]
[h3]I used Dismantle Any Car before. How do I switch?[/h3]
[list]
[*] Disable the old mod and enable this one. Nothing in the save needs fixing.
[*] Set the loot multiplier again on this mod's sandbox page.
[/list]
=== 💬 Feedback
[list]
[*] [b][url=https://github.com/Minidoracat/MinidoracatDismantleFor42/issues]GitHub Issues[/url][/b]
[*] [b][url=https://discord.gg/Gur2V67]Discord[/url][/b]: please include
[list]
[*] Game mode (single player or multiplayer)
[*] What happened and the steps
[*] Error messages, if any
[/list]
[/list]
