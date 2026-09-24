# Upgrader Tracker

Server-only Fabric mod for the Minecraft stack (`compose/minecraft`). It hooks
Upgrade Items' `UpgraderMenu` and:

- announces in chat every win below `announceBelowChance` (default 20%), once
  the wheel stops;
- tracks each player's spins, wins, value staked and value won (Upgrader
  value), saved to `world/upgrader_tracker.json`;
- mirrors each player's net to the `upgrader_net` scoreboard objective
  (`/scoreboard objectives setdisplay list upgrader_net` to show it in tab);
- adds `/upgrader stats [player]`, `/upgrader top [net|staked|won|wins|spins]`
  and, for ops, `/upgrader reset <player|all>`.

Players don't need it installed. Settings live in
`compose/minecraft/config/upgrader-tracker.json`.

## Building

Needs JDK 25. The built jar is committed to `compose/minecraft/mods/`, which
the server copies into `/data/mods` on start.

```sh
./gradlew build
cp build/libs/upgrader-tracker-*.jar ../../compose/minecraft/mods/
```

Remove the old jar from `compose/minecraft/mods/` when the version changes.

## Upgrade Items updates

The mixin targets Upgrade Items 1.2.0 internals (`startUpgrade`,
`applyResult`, and the `target`, `targetCount` and `pendingWin` fields). It is
not required, so if an update renames them the server still starts and logs a
mixin error, and announcements and tracking stop until this is rebuilt against
the new version (`upgrader_version` in `gradle.properties` is the Modrinth
version id).
