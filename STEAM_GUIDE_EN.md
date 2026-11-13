<!-- 指南網址：https://steamcommunity.com/sharedfiles/filedetails/?id=3838984195 -->
<!-- Steam 指南稿源（英文）：MOD 的完整說明以本指南為準，簡介只放摘要。格式、版面與同步方式見 pz-family-docs/release.md「完整說明：Steam 指南」 -->
<!-- 標題：📖 Minidoracat Repair & Dismantle Any Car MP Mod Guide: Part Repair, Dismantling and Sandbox Options -->
<!-- 摘要：Full guide for the mod that repairs and dismantles any vehicle: how to repair parts, repair methods and materials for each part type, Repair All Parts, engine rebuild, part salvage, tire sealant, dismantling vehicles, what a multiplayer server checks, sandbox options, known limits and FAQ. -->
=== 🚀 Quick Start
[b]繁體中文版：[/b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=3838984184]Minidoracat Repair & Dismantle Any Car MP 完整說明[/url]

The mod (Steam Workshop):
https://steamcommunity.com/sharedfiles/filedetails/?id=3838982743
[list]
[*] [b]Game version[/b]: Build 42.22.2 or newer. No other mods required.
[*] [b]Modes[/b]: single player, multiplayer and dedicated servers. In multiplayer the server must enable this mod.
[*] [b]Add/remove mid-save[/b]: safe either way. After removal, repaired parts and rebuilt engines stay as they are; the repair methods, salvage recipes and tire sealant from this mod disappear, and intact vehicles go back to vanilla and cannot be dismantled.
[/list]
[h3]Repairing[/h3]
[olist]
[*] [b]Open Vehicle Mechanics[/b]: right-click a vehicle and choose "Vehicle Mechanics".
[*] [b]Right-click a part[/b]: right-click a damaged part, choose "Repair" and pick a method.
[*] [b]Read the tooltip[/b]: hover over a method to see the materials, skills, how much it repairs and the chance of success.
[*] [b]Start[/b]: your character walks to the part and starts the repair.
[/olist]
[h3]Dismantling[/h3]
[olist]
[*] [b]Get the tools[/b]: a welding mask and a full propane torch (10 uses left).
[*] [b]Right-click[/b]: right-click a vehicle and choose "Dismantle Vehicle".
[*] [b]Confirm[/b]: if items are still inside, you are asked first.
[*] [b]Done[/b]: the vehicle is gone for good and the materials drop where it stood.
[/olist]
=== 🧰 Part Repair
{{img:03-repair-en.jpg}}
[list]
[*] [b]Which parts[/b]: every vehicle part has repair methods, including parts from vehicle mods. When the game starts, parts are sorted into 15 types by name, so new vehicles do not need a mod update.
[*] [b]Repair while installed[/b]: in Vehicle Mechanics, right-click a part and choose "Repair". The option does not appear when the part is at full condition.
[*] [b]Removed parts[/b]: for a part in your inventory, right-click it there and repair it the vanilla way.
[*] [b]Option names[/b]: each option shows the method, such as "Tape It Up" or "Weld". When one method takes different materials, the material is shown in brackets.
[*] [b]Tooltip[/b]: each material and skill shows "have/need". Anything missing is red and marked "(not enough)". The last lines show how much it repairs and the chance of success.
[*] [b]Materials[/b]: just carry them. Materials inside bags in your inventory are taken out before the repair starts.
[*] [b]Walking[/b]: your character walks to the part. For parts under the hood, the hood is opened first and closed afterwards.
[*] [b]Welding[/b]: welding methods equip the propane torch, and put on your welding mask if you carry one.
[*] [b]Brakes and suspension[/b]: remove the tire on that side first. The tooltip says "Remove first:" and which tire.
[*] [b]Parts that already have repairs[/b]: if vanilla or another mod already gives a part repair methods, this mod does not add a second set, and the part keeps its own methods.
[*] [b]Time and XP[/b]: this mod's methods take longer than vanilla ones. A successful repair gives skill XP like vanilla. Both can be changed in the sandbox options.
[/list]
=== 🧰 Repair Methods and Materials
[list]
[*] [b]How to read it[/b]: materials joined with "+" are all needed; "or" means pick one.
[*] [b]Uses[/b]: Duct Tape, Glue, Epoxy, Thread and the propane torch count remaining uses. Other materials count items. The propane torch is called "Welding Torch" in game.
[*] [b]How much it repairs[/b]: within a part type, methods lower in the table usually repair more. When a method takes different materials, the first one listed repairs more. The exact amount depends on your skills; the tooltip shows it.
[/list]
[table]
[tr][th]Part type[/th][th]Method[/th][th]Materials[/th][th]Skills[/th][/tr]
[tr][td]Doors[/td][td]Tape It Up[/td][td]Duct Tape 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Doors[/td][td]Screw On a Patch[/td][td]Screws 6 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Mechanics 2[/td][/tr]
[tr][td]Doors[/td][td]Weld[/td][td]Torch 2 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Welding 2, Mechanics 2[/td][/tr]
[tr][td]Hood, trunk lid[/td][td]Tape It Up[/td][td]Duct Tape 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Hood, trunk lid[/td][td]Screw On a Patch[/td][td]Screws 6 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Mechanics 2[/td][/tr]
[tr][td]Hood, trunk lid[/td][td]Weld[/td][td]Torch 2 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Welding 1, Mechanics 2[/td][/tr]
[tr][td]Trunks and racks[/td][td]Tape It Up[/td][td]Duct Tape 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Trunks and racks[/td][td]Screw On a Patch[/td][td]Screws 6 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Mechanics 2[/td][/tr]
[tr][td]Trunks and racks[/td][td]Weld[/td][td]Torch 2 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Welding 3, Mechanics 2[/td][/tr]
[tr][td]Gas tank[/td][td]Seal with Epoxy[/td][td]Epoxy 2[/td][td]Mechanics 2[/td][/tr]
[tr][td]Gas tank[/td][td]Weld[/td][td]Torch 2 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Welding 3, Mechanics 2[/td][/tr]
[tr][td]Armor and bumpers[/td][td]Screw On a Patch[/td][td]Screws 6 + Steel Sheet 1 or Scrap Metal 3[/td][td]Mechanics 2[/td][/tr]
[tr][td]Armor and bumpers[/td][td]Weld[/td][td]Torch 3 + Steel Sheet 1 or Steel Sheet - Small 2[/td][td]Welding 4, Mechanics 2[/td][/tr]
[tr][td]Muffler[/td][td]Tape It Up[/td][td]Duct Tape 3[/td][td]Mechanics 1[/td][/tr]
[tr][td]Muffler[/td][td]Weld[/td][td]Torch 2 + Iron Pipe 1 or Steel Sheet - Small 2[/td][td]Welding 2, Mechanics 2[/td][/tr]
[tr][td]Seats[/td][td]Tape It Up[/td][td]Duct Tape 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Seats[/td][td]Sew (Leather Strips)[/td][td]Thread 2 + Leather Strips 3[/td][td]Tailoring 2[/td][/tr]
[tr][td]Seats[/td][td]Sew (Denim Strips, Rag)[/td][td]Thread 2 + Denim Strips 3 or Rag 4[/td][td]Tailoring 1[/td][/tr]
[tr][td]Glove box[/td][td]Tape It Up[/td][td]Duct Tape 2 or Glue 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Windows[/td][td]Tape It Up[/td][td]Duct Tape 3[/td][td]Mechanics 1[/td][/tr]
[tr][td]Windows[/td][td]Replace the Glass[/td][td]Glue 2 + Glass Pane 1[/td][td]Mechanics 3[/td][/tr]
[tr][td]Tires[/td][td]Patch the Tire (Tire Piece)[/td][td]Glue 1 + Tire Piece 1[/td][td]Mechanics 2[/td][/tr]
[tr][td]Tires[/td][td]Patch the Tire (Duct Tape)[/td][td]Glue 1 + Duct Tape 3[/td][td]Mechanics 1[/td][/tr]
[tr][td]Tires[/td][td]Use Tire Sealant[/td][td]Tire Sealant 1[/td][td]Mechanics 1[/td][/tr]
[tr][td]Brakes[/td][td]Bolt On New Metal[/td][td]Nuts and Bolts 2 + Steel Sheet - Small 1 or Scrap Metal 3[/td][td]Mechanics 3[/td][/tr]
[tr][td]Brakes[/td][td]Weld[/td][td]Torch 1 + Steel Sheet - Small 1[/td][td]Welding 2, Mechanics 3[/td][/tr]
[tr][td]Suspension[/td][td]Bolt On New Metal[/td][td]Nuts and Bolts 4 + Steel Rod 1 or Iron Pipe 1[/td][td]Mechanics 4[/td][/tr]
[tr][td]Suspension[/td][td]Weld[/td][td]Torch 2 + Steel Rod 1 or Iron Pipe 1[/td][td]Welding 3, Mechanics 4[/td][/tr]
[tr][td]Battery[/td][td]Rewire[/td][td]Electrical Wire 2 or Scrap Electronics 3[/td][td]Electrical 2, Mechanics 1[/td][/tr]
[tr][td]Other accessories[/td][td]Tape It Up[/td][td]Duct Tape 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Other accessories[/td][td]Screw On a Patch[/td][td]Screws 4 + Steel Sheet - Small 1 or Scrap Metal 2[/td][td]Mechanics 1[/td][/tr]
[tr][td]Other accessories[/td][td]Weld[/td][td]Torch 1 + Steel Sheet - Small 1[/td][td]Welding 2, Mechanics 1[/td][/tr]
[/table]
[list]
[*] [b]Other accessories[/b]: any part whose name does not match one of the types above.
[/list]
=== 🧰 Repair All Parts
{{img:04-repair-all-en.jpg}}
[list]
[*] [b]Where[/b]: in Vehicle Mechanics, right-click any part and choose "Repair All Parts".
[*] [b]Check the list first[/b]: the tooltip lists the parts it will repair and the method for each (green), then the parts it skips and why (red), such as a missing material or a tire that must come off first. Each list shows up to 12 parts; the rest are counted.
[*] [b]Which parts[/b]: installed parts that are not at full condition and have a repair method, vanilla methods included.
[*] [b]Which method[/b]: for each part, the method that repairs the most with the materials and skills you have right now.
[*] [b]One at a time[/b]: it repairs one part, then picks the next, counting the materials already used. Parts you no longer have materials for are skipped.
[*] [b]Once per part[/b]: each part is repaired once. If some are still not full, choose "Repair All Parts" again.
[*] [b]If it stops[/b]: if you cancel one of the repairs, or the server rejects one, the remaining parts are not repaired. Choose "Repair All Parts" again.
[/list]
=== 🧰 Engine Rebuild and Heater Repair
[h3]Rebuild Engine[/h3]
{{img:05-rebuild-en.jpg}}
[list]
[*] [b]When it appears[/b]: the engine condition is at 100 (use the vanilla "Repair Engine" first) and engine quality is below 100.
[*] [b]Where[/b]: in Vehicle Mechanics, right-click the engine and choose "Rebuild Engine".
[*] [b]Needs[/b]: a wrench (not used up), 10 Spare Engine Parts (sandbox option) and Mechanics 5. If this vehicle's vanilla engine repair level is higher than 5, that level is used.
[*] [b]Effect[/b]: +10 engine quality each time, up to 100. Engine power is recalculated from quality the vanilla way.
[*] [b]Tooltip[/b]: shows "have/need" for the tool, materials and skill, and the quality before and after.
[/list]
[h3]Repair Heater[/h3]
[list]
[*] [b]Where[/b]: in Vehicle Mechanics, right-click the heater and choose "Repair Heater".
[*] [b]Needs[/b]: a screwdriver (not used up), Scrap Electronics 2, Electrical Wire 1 and Mechanics 3. If this vehicle's vanilla engine repair level is higher than 3, that level is used.
[*] [b]Effect[/b]: restores 25 + 5 × your Mechanics level condition each time, up to 100.
[*] [b]Note[/b]: the vanilla heater works the same at any condition. This option only restores the condition shown in Vehicle Mechanics; how warm the heater gets stays vanilla.
[/list]
[list]
[*] [b]Both[/b]: your character walks to the part, opens the hood first and closes it afterwards. A locked hood is unlocked first.
[/list]
=== 🧰 Part Salvage
{{img:07-salvage-en.jpg}}
[list]
[*] [b]Where[/b]: with a removed part in your inventory, right-click it and choose the option that starts with "Salvage", such as "Salvage Car Door". Broken parts work too. The part is used up.
[*] [b]Output[/b]: one fixed material, plus 3 rolls for extra materials (sandbox option).
[*] [b]Roll chance[/b]: 40%, plus 3% for each level of Mechanics and of the skill for that part type. Metal parts use Welding, seats use Tailoring, batteries use Electrical and glove boxes use Mechanics.
[*] [b]Parts without salvage[/b]: tires and windows. Tires can be cut with the vanilla recipe.
[/list]
[table]
[tr][th]Recipe[/th][th]Tools[/th][th]Skill[/th][th]Fixed output[/th][th]Extra materials[/th][/tr]
[tr][td]Salvage Car Door, Hood, Trunk Lid, Trunk or Rack[/td][td]Torch 3, welding mask[/td][td]Welding 2[/td][td]Steel Sheet - Small[/td][td]Steel Sheet, Steel Sheet - Small, Scrap Metal, Screws[/td][/tr]
[tr][td]Salvage Vehicle Armor[/td][td]Torch 3, welding mask[/td][td]Welding 3[/td][td]Steel Sheet - Small[/td][td]Steel Sheet, Steel Sheet - Small, Scrap Metal, Steel Rod[/td][/tr]
[tr][td]Salvage Gas Tank[/td][td]Torch 2, welding mask[/td][td]Welding 2[/td][td]Scrap Metal[/td][td]Steel Sheet - Small, Scrap Metal, Iron Pipe[/td][/tr]
[tr][td]Salvage Muffler[/td][td]Torch 2, welding mask[/td][td]Welding 1[/td][td]Scrap Metal[/td][td]Iron Pipe, Steel Sheet - Small, Scrap Metal[/td][/tr]
[tr][td]Salvage Brake[/td][td]Torch 1, welding mask[/td][td]Welding 1[/td][td]Scrap Metal[/td][td]Scrap Metal, Nuts and Bolts, Steel Sheet - Small[/td][/tr]
[tr][td]Salvage Suspension[/td][td]Torch 2, welding mask[/td][td]Welding 2[/td][td]Scrap Metal[/td][td]Steel Rod, Scrap Metal, Nuts and Bolts[/td][/tr]
[tr][td]Salvage Vehicle Accessory[/td][td]Torch 1, welding mask[/td][td]Welding 1[/td][td]Scrap Metal[/td][td]Steel Sheet - Small, Scrap Metal, Screws[/td][/tr]
[tr][td]Salvage Car Seat[/td][td]Scissors or a sharp knife[/td][td]—[/td][td]Rag[/td][td]Rag, Leather Strips, Scrap Metal[/td][/tr]
[tr][td]Salvage Car Battery[/td][td]Screwdriver[/td][td]—[/td][td]Scrap Electronics[/td][td]Electrical Wire, Scrap Electronics, Scrap Metal[/td][/tr]
[tr][td]Salvage Glove Box[/td][td]Screwdriver[/td][td]—[/td][td]Scrap Metal[/td][td]Steel Sheet - Small, Scrap Metal, Screws[/td][/tr]
[/table]
=== 🧰 Tire Sealant
{{img:08-sealant-en.jpg}}
[list]
[*] [b]Use[/b]: the "Use Tire Sealant" method for tires. One can, one repair. It needs only Mechanics 1 and repairs more than patching.
[*] [b]Where to find it[/b]: shelves and crates in mechanic shops, car supply stores, gas stations and garages, and in the trunks and glove boxes of mechanic vehicles.
[/list]
=== 🧰 Dismantling a Vehicle
{{img:01-menu-en.jpg}}
[list]
[*] [b]Which vehicles[/b]: all of them. Intact cars and trailers show "Dismantle Vehicle". Burnt and smashed vehicles show the vanilla "Dismantle Car Wreck".
[*] [b]Tools[/b]: the same as dismantling a wreck in vanilla. One welding mask and 10 uses of a propane torch, which is one full torch. The tooltip lists what you are missing.
[*] [b]Welding requirement[/b]: a sandbox option can require a Welding level to dismantle intact vehicles. The default is none. Wrecks stay vanilla.
[*] [b]Cost[/b]: each vehicle uses 10 torch uses, a whole torch.
[*] [b]Time[/b]: the same as dismantling a wreck in vanilla. Higher Welding is faster. A sandbox option changes the time for intact vehicles.
[*] [b]Materials[/b]: the same metal materials and Welding XP as a vanilla wreck. Higher Welding gives more.
[/list]
[h3]Remove Parts, Then Dismantle[/h3]
{{img:06-strip-en.jpg}}
[list]
[*] [b]Where[/b]: right-click an intact vehicle and choose "Remove Parts, Then Dismantle".
[*] [b]What it does[/b]: removes every part you are able to remove, one by one, then dismantles the vehicle. This takes a long time.
[*] [b]Parts you cannot remove[/b]: removing follows the vanilla rules. Parts you lack the tools, skills or recipe for, a gas tank that is not empty, and parts vanilla never lets you remove (such as the glove box) stay on the vehicle and are destroyed with it.
[*] [b]Dismantle requirements[/b]: the same as "Dismantle Vehicle", so bring a welding mask and a full propane torch.
[*] [b]If it stops[/b]: if you cancel one of the removals, the rest do not continue and the vehicle is not dismantled. Parts already removed stay with you or on the ground.
[/list]
=== 📦 When Items Are Still Inside
{{img:02-confirm-en.jpg}}
[list]
[*] [b]Confirmation[/b]: if the trunk, glove box or seats still hold items, the mod shows how many first.
[*] [b]After you confirm[/b]: the items are destroyed with the vehicle. They do not drop on the ground, so take out what you want to keep.
[*] [b]If the item count goes up after you confirm[/b]: when the vehicle holds more items than you confirmed, the dismantle stops and the vehicle and items stay. Right-click and choose "Dismantle Vehicle" again to confirm the new count.
[*] [b]Installed parts[/b]: tires, battery, seats and other parts still on the vehicle are destroyed too. Uninstall them first if you want them, or use "Remove Parts, Then Dismantle".
[/list]
=== 🌐 Multiplayer Servers
[list]
[*] [b]Server re-check[/b]: the server re-checks every dismantle, part repair, engine rebuild, heater repair and part salvage before applying the result.
[*] [b]If a check fails[/b]: a vehicle being dismantled stays and no materials drop; a part being repaired or rebuilt stays the same and no materials are used.
[*] [b]Vanilla actions[/b]: this mod reuses the vanilla dismantle and repair actions and adds no network commands. Vehicle protection mods that guard those vanilla actions work without changes.
[*] [b]Vehicle protection mods[/b]: with Minidoracat Vehicle Manager, a claimed vehicle can only be dismantled by its owner or an admin.
[*] [b]Server log[/b]: the server writes one line per event to the MinidoracatAnyCar log file in the Logs folder:
[list]
[*] Dismantle: account, vehicle type, vehicle id, coordinates, number of parts and number of items inside.
[*] Repairing an installed part with this mod's methods: account, vehicle type, vehicle id, part, method, and condition before and after.
[*] Engine rebuild and heater repair: account, vehicle type, vehicle id, and the value before and after.
[/list]
[/list]
=== ⚙️ Sandbox Options and Defaults
On the "Repair & Dismantle Any Car" page of the sandbox options. In multiplayer the server applies them.
[table]
[tr][th]Option[/th][th]Default[/th][th]Description[/th][/tr]
[tr][td]Dismantle Loot Multiplier[/td][td]1.0[/td][td]Multiplies the materials you get from dismantling a vehicle or a wreck, from 0 to 10. 1.0 is vanilla.[/td][/tr]
[tr][td]Dismantle: Welding Level Required[/td][td]0[/td][td]Welding level needed to dismantle an intact vehicle, from 0 to 10. 0 means no requirement. Wrecks stay vanilla.[/td][/tr]
[tr][td]Dismantle: Time Multiplier[/td][td]1.0[/td][td]Multiplies the time to dismantle an intact vehicle, from 0.1 to 10. 1.0 is the same as a wreck.[/td][/tr]
[tr][td]Part Repair[/td][td]On[/td][td]The repair methods from this mod, Repair All Parts and Repair Heater. Off leaves only vanilla repairs.[/td][/tr]
[tr][td]Part Repair: Time Multiplier[/td][td]1.0[/td][td]Multiplies the time of this mod's repair methods, from 0.1 to 10.[/td][/tr]
[tr][td]Part Repair: XP Multiplier[/td][td]1.0[/td][td]Multiplies the XP from a successful repair with this mod's methods, from 1 to 10. 1.0 is vanilla.[/td][/tr]
[tr][td]Part Salvage[/td][td]On[/td][td]Lets you break removed parts down into materials.[/td][/tr]
[tr][td]Part Salvage: Loot Multiplier[/td][td]1.0[/td][td]Multiplies the number of extra material rolls, from 0 to 10. 1.0 is 3 rolls.[/td][/tr]
[tr][td]Engine Rebuild[/td][td]On[/td][td]Raise engine quality with Spare Engine Parts once the engine is at full condition.[/td][/tr]
[tr][td]Engine Rebuild: Spare Parts per Step[/td][td]10[/td][td]Spare Engine Parts used each time, from 1 to 50. Each step adds 10 quality.[/td][/tr]
[/table]
=== ⚠️ Known Limits
[list]
[*] [b]Stay close[/b]: you can move while dismantling, but the action stops if you go more than about 6 tiles away. For repairs the limit is about 12 tiles.
[*] [b]Passengers and animals[/b]: a vehicle with someone inside, or a trailer with animals, cannot be dismantled. Get them out first.
[*] [b]Only the item count is compared[/b]: if someone takes one item out and puts another in after you confirm, or fills a bag that was already inside, the count does not go up, the dismantle does not stop, and those items are destroyed with the vehicle.
[*] [b]Part types come from names[/b]: parts from vehicle mods are sorted by name. Parts whose name gives no hint go to "Other accessories", so their repair methods may not fit the real part well.
[*] [b]Repair Heater[/b]: only restores the condition shown in Vehicle Mechanics. The vanilla heater works the same at any condition.
[*] [b]No vehicle protection[/b]: this mod does not care who owns a vehicle. To protect your vehicles, use a vehicle protection mod.
[*] [b]Other dismantling mods[/b]: do not enable other mods that change the dismantle action at the same time. The menu shows duplicates and the mods override each other.
[/list]
=== ❓ FAQ
[h3]There is no "Repair" on a part?[/h3]
[list]
[*] The part is already at full condition, or the "Part Repair" sandbox option is off.
[*] Removed parts are repaired by right-clicking them in your inventory.
[/list]
[h3]A repair option is red?[/h3]
[list]
[*] Hover over it. The tooltip marks the missing materials or skills in red. For brakes and suspension it says which tire to remove first.
[/list]
[h3]There is no "Rebuild Engine"?[/h3]
[list]
[*] Bring the engine condition to 100 first with the vanilla "Repair Engine".
[*] Engine quality is already 100, or the "Engine Rebuild" sandbox option is off.
[/list]
[h3]I repaired the heater but the car is still cold?[/h3]
[list]
[*] The vanilla heater works the same at any condition. "Repair Heater" only restores the condition shown. Use the heater the vanilla way.
[/list]
[h3]There is no salvage option when I right-click a part in my inventory?[/h3]
[list]
[*] Make sure the "Part Salvage" sandbox option is on.
[*] Tires and windows have no salvage recipe. Tires can be cut with the vanilla recipe.
[*] If the option cannot be selected, its tooltip lists the missing tools or skills.
[/list]
[h3]There is no "Dismantle Vehicle" option?[/h3]
[list]
[*] Make sure the mod is enabled. In multiplayer the server must enable it too.
[*] Burnt and smashed vehicles show the vanilla "Dismantle Car Wreck" instead.
[/list]
[h3]"Dismantle Vehicle" is red?[/h3]
[list]
[*] Hover over it. The tooltip lists what is missing in red: welding mask, torch uses, Welding level, someone inside, or animals in the trailer.
[/list]
[h3]The action stops halfway?[/h3]
[list]
[*] It stops if the torch leaves your hand, you move too far away, someone enters the vehicle, or the vehicle ends up holding more items than you confirmed.
[/list]
[h3]I used Dismantle Any Car before. How do I switch?[/h3]
[list]
[*] Disable the old mod and enable this one. Nothing in the save needs fixing.
[*] Set the loot multiplier again on this mod's sandbox page.
[/list]
=== 💬 Feedback
[list]
[*] [b][url=https://github.com/Minidoracat/MinidoracatAnyCarFor42/issues]GitHub Issues[/url][/b]
[*] [b][url=https://discord.gg/Gur2V67]Discord[/url][/b]: please include
[list]
[*] Game mode (single player or multiplayer)
[*] What happened and the steps
[*] Error messages, if any
[/list]
[/list]
