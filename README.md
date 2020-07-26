# D3bot

This is a fork of [/Azurblau/AzBot](https://github.com/Azurblau/AzBot) with new features and bug fixes.

Here is a list of notable changes compared to the original version:

- Unidirectional links.
- Links which are only usable by fast zombies.
- Some more specific movement instructions for nodes to allow bots to handle obstacles better. (Duck when on a node, duck when moving towards a node, aim straight when on a node, aim straight towards a node, ...)
- Conditions for nodes. (Allow or disallow the use of a node, if the said node is close to specific entities like doors, breakables, physic props, etc.)
- Pouncing behavior for fast zombies or zombies based on that class. This makes these zombies much more dangerous, as they will hit you with a high certainty if you are within their jump range. They'll also use that ability to jump to the next or second next node if possible.
- Small adjustments to the inner workings of the pathfinding algorithm. For example bots will now walk towards the next node until they are within its reach, and not until they are closest to it. This makes the bots movement behavior more predictable for navmesh creators, and also prevents bots from running in circles sometimes.
- Zombies will only attack if the target is within reach. This makes wraith and fast zombie attacks much more surprising and effective.
- Fix bots glitching outside of the map if they spawn inside a trigger_zombieclass brush.
- Fix zombie class selection logic for bots.
- Bots now crouch when their target is low.
- Prevent links linking a node to itself.
- Github friendly navmesh format.
- More example navmeshes, which make use of all the new features. See [NAVMESHES](NAVMESHES.md)
- Survivor bots.
- All settings in a separate lua file. (`sv_config.lua`)
- Named bots (See `/lua/d3bot/names` to adjust or add new name lists)
- Climbing bots. (Thanks to [orecros])
- More advanced edit modes. (Thanks to necrossin)
- Improved navmesh drawing.
- Translations:
  - Chinese Simplified (Thanks to [XY]EvansFix)
  - Chinese Traditional (Thanks to [Half1569])
  - Czech (Thanks to kekosminek)
  - Danish (Thanks to MRBennetsen)
  - Dutch (Thanks to Ubister)
  - English
  - French (Thanks to [FR]Angel-Neko_X)
  - German
  - Italian (Thanks to [Wolfaloo])
  - Korean
  - Polish (Thanks to [Halamix2])
  - Portuguese(Brazil) (Thanks to GMBR | $herlock Bu$ter)
  - Russian (Thanks to [Blueberryy])
  - Spanish (Thanks to [Fafy2801])
  - Turkish (Thanks to ᴇXғɪʀᴇᴄʜʀᴏᴍᴇ~)
  - Ukrainian (Thanks to [ErickMaksimets])
- Some smaller things i possibly forgot.

This fork is backward compatible, but there are some changes which prevents you to use navmeshes from this fork in the original version. To make them work just replace all occurrences of `\n` with `;`.
If you come from an older version, you may have to move the navmeshes from `garrysmod/data/azbot/navmesh/map/...` to `garrysmod/data/d3bot/navmesh/map/...`.

Everything below here is the original readme, but with updated information:

![Bots in action](./media/screenshot1.jpg)
Server: pussfoot.ovh:27015 [EU] Zombie Survival | AzBot | Custom Content

# AzBot

A very primitive AI for GMod bots primarily designed to work with Jetboom's Zombie Survival gamemode.

AzBot uses A* pathfinding with directed Monte Carlo-based execution.

## License

I, the author, have not decided on a license yet.

Though I won't take measures against illegitimate usage unless I have reasons to do so.

**Things I'll accept:**

- Using AzBot on your own server even if it accepts donations.
- Making derivatives (aka copies with changes) of AzBot or its derivatives as long as it's made clear at least in-game that they're AzBot derivatives.
  
  I suggest giving the derivative your own name (e.g. BobBot) and putting e.g. "BobBot is based on AzBot" in your MotD, GUI, HUD or automatic chat messages.

**Things I won't like:**

- Selling AzBot or its derivatives (I don't plan to sell it either).

## Prerequisites

- Zombie Survival gamemode
- Multiplayer (bots use player slots, local server is sufficient)
- ULX (navmesh editor, `!botmod` and `!human` commands)
- NavMeshes (see "How to create navmeshes" below)

## Installation

- Make sure you have [ULX](http://steamcommunity.com/sharedfiles/filedetails/?id=557962280) and [ULib](http://steamcommunity.com/sharedfiles/filedetails/?id=557962238) installed.
- Download the addon and extract it into your `garrysmod/addons/` folder, to get the following file structure: `garrysmod/addons/d3bot/lua/...`, `garrysmod/addons/d3bot/data/...`, and so on. It's important that the folder inside `addons` is named `d3bot` (Don't name it `D3bot` or anything else), otherwise it will not work!
- Copy all navmeshes from the addon's path `data/d3bot/navmesh/map/...` to `garrysmod/data/d3bot/navmesh/map/...`.
- Adjust the configuration in `lua/d3bot/sv_config.lua` as you wish.
- Done

## How to test

- Download and install [zs_villagehouse.bsp](https://garrysmods.org/download/16130/zs-villagehousezip).
- Launch your server with Zombie Survival gamemode on zs_villagehouse. (Or Garry's Mod with a 32 slot local server, if you have installed D3bot to your Garry's Mod installation directly.)
- If bots spawn and chase after you, everything is working as intended.
- Type `!bot viewmesh ^` to see the navmesh and `!botmod -999` to kick all bots (both commands require ULX).

## How to update

- If you have made any changes to `lua/d3bot/sv_config.lua`, save it first.
- Remove the `d3bot` folder out of your addons directory.
- Install the newer version of D3bot.
- Copy your saved `lua/d3bot/sv_config.lua` back. Or better: check for differences manually, as it's possible that the structure of the file changed.

![Image of the navmesh editor](./media/navmesh1.jpg)

## How to create navmeshes

- Use the chat command `!bot editmesh ^` to enter the mesh editor.
  - Use IN_RELOAD to cycle through the edit modes:
    - Create node: Place nodes with IN_ATTACK.
    - Link nodes: Link nodes by selecting the first then the second node, both with IN_ATTACK. Clear selection with IN_RELOAD.
    - Merge/Split/Extend nodes: This is a bit more complicated edit mode:
      - Merge: Select two nodes with IN_ATTACK to merge them.
      - Split: Select a node with IN_ATTACK and then use IN_ATTACK2 to split the node horizontally to your viewport at your aiming point.
      - Extend: Select a node with IN_ATTACK and then use IN_ATTACK2 to create a new node between your selected node and your aiming point. The node will be extended along the axis you are looking.
      - Use IN_RELOAD to clear the selection when you miss-click, otherwise it may happen that you accidentally merge two nodes.
      - You can quickly delete a node by selecting it two times with IN_ATTACK. (Basically it merges the node with itself, so it's a nice ~~bug~~ feature)
    - Reposition nodes: Select a node with IN_ATTACK and use IN_ATTACK to reposition it or IN_ATTACK2 to reposition it using only the aim axis (X, Y or Z). Clear selection with IN_RELOAD.
    - Resize nodes: Select a node with IN_ATTACK and use IN_ATTACK2 to resize it towards the aim axis (X or Y). Clear selection with IN_RELOAD.
    - Copy nodes: Select the nodes with IN_ATTACK and copy them with IN_ATTACK2 (All selected nodes are copied along the look direction to the target position, the first selected node is taken as the origin).
    - Set/Unset Last Parameter: Apply the last used parameter with IN_ATTACK, or remove the last used parameter with IN_ATTACK2.
    - Delete items: Delete a node or link with IN_ATTACK, clear node areas with IN_ATTACK2.
- Use `!bot setparam <id> <name> <value>` (example: `!bot setparam 1 jump disabled`) to set or unset (by omitting \<value\>) special parameters:
  - Node parameters:
    - Jump = Disabled: Bots won't jump if located in this node.
    - Jump = Always: Bots will always jump if located in this node.
    - JumpTo = Disabled: Bots won't jump if heading towards this node.
    - JumpTo = Always: Bots will always jump if heading towards this node.
    - Duck = Disabled: Bots won't crouch if located in this node.
    - Duck = Always: Bots will always crouch if located in this node.
    - DuckTo = Disabled: Bots won't crouch if heading towards this node.
    - DuckTo = Always: Bots will always crouch if heading towards this node.
    - Climbing = Needed: Only bots with the ability to climb will path through this node. If the node is above the bot, the will look towards this node, jump, and climb towards the node.
    - Wall = Suicide: Bots suicide if trying to navigate towards this node higher than crouch-jumping height. Use this when respawn is the only way to get to that node.
    - Wall = Retarget: Same as Wall = Suicide but target is changed instead of suiciding. If no other targets are available, target remains the same. Use this for unreachable or low priority nodes.
    - See = Disabled: Bot does not approach target in straight line even if target is visible to him unless he is on the same node as the target. Use this on heightened nodes visible to, but not directly accessible from lower nodes.
    - Aim = Straight: Bot goes straight to the next node. Use this if bots need to get through small holes in the floor or walk on narrow paths without falling down.
    - AimTo = Straight: Bot goes straight to this node. Use this if bots need to get through narrow windows or small holes in the floor.
    - Cost: Add a penalty for paths using this node. Higher values makes it less likely for bots to use a path containing this node.
    - Condition = Unblocked: Bots will only use this node for pathfinding if there is no entity within a range of one inch. Detected entities are func_breakable, prop_physics, prop_dynamic, prop_door_rotating, func_door, func_physbox_multiplayer, func_movelinear.
    - Condition = Blocked: Opposite of above. Use this for breakable pathways.
    - BlockBeforeWave: Bots will not use this node for pathfinding until the current wave is greater than or equal to the given value.
    - BlockAfterWave: Bots will not use this node for pathfinding if the current wave is greater than the given value.
    - DMGPerSecond: Apply damage to human players and entities located on this node.
    - BotMod: Once a non bot player passes this node, the given offset will be applied to the zombie count target. Useful to adjust the bot count on objective maps.
  - Link parameters:
    - Cost: Add a penalty for paths using this link. Higher values makes it less likely for bots to use a path containing this link.
    - Direction = Forward: Only allow paths from the first to the second element of the link. `!bot setparam 1-2 Direction Forward` will only allow the bot to move from 1 to 2.
    - Direction = Backward: Same as above, but backwards.
    - Pouncing = Needed: Only classes with the ability to pounce/leap can use this link.
- Use `!bot reloadmesh` to discard changes.
- Use `!bot savemesh` to save the changes to `garrysmod/data/d3bot/navmesh/map/<mapname>.txt`.
- Use `!bot setmapparam <name> <value>` (example: `!bot setmapparam botmod 5`) to set or unset (by omitting \<value\>) map specific parameters:
  - BotMod: Map specific zombie count formula offset.
  - ZPH: Zombie per Human ratio override.
  - ZPHM: Zombie per Human ratio maximum override. Max amount of the zombie count target. (BotMod can offset the target beyond this limit)
  - ZPHW: Zombies per (Human * Wave) override.
  - ZPM: Zombies per minute override.
  - ZPW: Zombies per wave override.
  - SPP: Survivor bots per total player (non bot) count.
  - SCA: Similar to BotMod, but for the survivor bot count. Survivors will only spawn pre round.
  
- The same commands can be used from the console, just replace `!bot` with `d3bot`. (example: `d3bot editmesh ^`)

## Notes

- Restart the map after saving the mesh for the first time. Every map that has a navmesh at addon loading time is treated as a bot map (enabling the bot count director, `!human` command and survivor bonuses if configured). Move the navmesh file if that effect is not desired.
- Use `!botmod` to change the desired zombies count. Examples: `!botmod -100` for no bots, `!botmod 100` for full server minus 2 slots for joining players, default is `!botmod 0`.
- Navmeshes can be edited on the fly. Feel free to fix your meshes during testing.
- This sketch might help: [navmesh2.png](./media/navmesh2.png)
- Having sized nodes helps locating (= "what node are you in?"). Nodes without an area use a small sphere instead.
- Once a bot enters a node's area/sphere, he immediately moves towards the next node's position.
- It is recommended to use sized nodes for rooms/areas and nodes without an area for doors. Each hallway, intersection and groove should have their own sized node. For ladders, two nodes without an area, one at bottom and one at top, suffice.
- Locating works by proximity check. If a separate node lies behind a wall but closer to the middle of two distant linked nodes than them, bots may assume wrongly that they are located at the other node if they're in the middle. Avoid that by using a third sized node for the gap between the two linked nodes and re-link them.
- Once a bot sees the target, he moves straight for it (see also: See = Disabled parameter).
- All links are normally bidirectional (see also: Wall = Suicide parameter or Direction = Forward/Backward).
- Bots can take any route with tendency towards the shortest.
- Bots stubbornly move towards the next node unless they enter another node at time of path refresh (occurs roughly every second). Link wisely.
- Bots may aim too perfect, the precision can be changed inside `sv_config.lua` with the option `D3bot.FaceTargetOffshootFactor`. (Suggestion for the fix by [HordeRally ツ])

![Bots in action](./media/screenshot2.jpg)

## ToDo

Starting with highest public priority:

- Making a config.txt for the static variables.
- Refactoring, e.g. stable API, stable navmesh standard, consistency, bot metatable, gamemode independence by adding hooks usable by gamemodes or gamemode-based plugins, ...
- Detailed linking e.g. required jump height, movement behavior (gap-jumping, ...), more link unlock conditions, ...
- Map information in navmeshes using a singleton item type solely for storing parameters (e.g. zombie count multiplier).
- Leap behavior for headcrab bots.
- Sloped nodes for more accurate locating of entities.
- Triangle-based nodes using vertices with automatic adjacent linking.
- Sub-paths in nodes for more accurate movement (no "wall-sliding").
- Equipment upgrading behavior for survivor bots.
- Caching of non-branching paths as a single node to optimize the pathfinding performance.

[Blueberryy]: https://github.com/Blueberryy
[Halamix2]: https://github.com/Halamix2
[orecros]: https://github.com/orecros
[Wolfaloo]: https://github.com/Wolfaloo
[Fafy2801]: https://github.com/Fafy2801
[Half1569]: https://github.com/Half1569
[ErickMaksimets]: https://github.com/ErickMaksimets
[Nightmare!]: https://steamcommunity.com/profiles/76561198171603670
