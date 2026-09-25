# Upgrader Tracker

Server-only Fabric mod for the Minecraft stack (`compose/minecraft`). It hooks
Upgrade Items' `UpgraderMenu` and:

- announces in chat every win below `announceBelowChance` (default 20%), once
  the wheel stops;
- tracks each player's spins, wins, value staked and value won (Upgrader
  value), saved to `world/upgrader_tracker.json`;
- mirrors each player's net to the `upgrader_net` scoreboard objective
  (`/scoreboard objectives setdisplay list upgrader_net` to show it in tab);
- caps what Upgrade Items' `minChance` floor can pay out: the floor applies in
  full to targets worth up to `floorJackpotCap` (default 36,000, ten diamond
  blocks) and shrinks in proportion above it, so a 1-cobblestone roll at 62
  diamond blocks is 0.016% instead of 0.1%. Rolls with fair odds above the
  floor are untouched, and the menu shows the same chance that is rolled;
- only lets `currencyItems` (default `minecraft:egg`) be staked: anything else
  won't go into the input slot and the player is told what the Upgrader takes.
  With one currency, other items' values only set what they pay out, so they
  can be repriced without anyone staking them for better odds. An empty list
  allows every item;
- makes the menu show the chance that is rolled: Upgrade Items works the
  displayed chance out from values rounded to whole numbers, which is far off
  for cheap items (64 blocks worth 1.35 each showed 67.5% instead of 50%);
- adds `/upgrader stats [player]`, `/upgrader top [net|staked|won|wins|spins]`
  and, for ops, `/upgrader reset <player|all>`.

Players don't need it installed. Settings live in
`compose/minecraft/config/upgrader-tracker.json`.

## Building

Needs JDK 25. The built jar is committed to `compose/minecraft/mods/`, which
the server copies into `/data/mods` on start.

```sh
./gradlew build
cp build/libs/upgrader-tracker-*.jar ../../compose/minecraft/mods/upgrader-tracker.jar
```

The jar keeps one unversioned name because the server copies `/mods` into
`/data/mods` without deleting anything there, so renamed jars would pile up
(Fabric loads the newest version when it finds duplicates).

## Upgrade Items updates

The mixins target Upgrade Items 1.2.0 internals (`UpgraderMenu.startUpgrade`,
`applyResult`, `syncToClient`'s `ClientboundUpgraderSyncPacket`, the `target`, `targetCount` and `pendingWin` fields, and
`UpgradeOdds.chance(double, double)`, and the input slot being the anonymous
`UpgraderMenu$2`). They are
not required, so if an update renames them the server still starts and logs a
mixin error, and announcements and tracking stop until this is rebuilt against
the new version (`upgrader_version` in `gradle.properties` is the Modrinth
version id).
