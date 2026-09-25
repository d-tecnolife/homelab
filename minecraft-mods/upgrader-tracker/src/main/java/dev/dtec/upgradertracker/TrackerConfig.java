package dev.dtec.upgradertracker;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import net.fabricmc.loader.api.FabricLoader;

/** config/upgrader-tracker.json; written with defaults when missing. */
public final class TrackerConfig {
	private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

	/** Wins at a chance strictly below this (0..1) are announced to the whole server. */
	public double announceBelowChance = 0.2;
	/** Scoreboard objective mirroring each player's net result; empty disables it. */
	public String scoreboardObjective = "upgrader_net";
	/**
	 * Upgrader value up to which the minChance floor applies in full; above it the floor shrinks in
	 * proportion, so a floor-propped roll is never worth more on average than one at this value.
	 * 0 leaves Upgrade Items' floor alone.
	 */
	public double floorJackpotCap = 36000;
	/**
	 * Item ids that can be staked in the Upgrader; anything else is refused. Keeping stakes to one
	 * currency means other items' values only set what they pay out, never what they are worth to
	 * gamble. Empty allows every item.
	 */
	public List<String> currencyItems = new ArrayList<>(List.of("minecraft:egg"));

	public static TrackerConfig load() {
		Path path = FabricLoader.getInstance().getConfigDir().resolve("upgrader-tracker.json");
		TrackerConfig config = new TrackerConfig();
		try {
			if (Files.exists(path)) {
				TrackerConfig read = GSON.fromJson(Files.readString(path), TrackerConfig.class);
				if (read != null) {
					config = read;
				}
			} else {
				Files.writeString(path, GSON.toJson(config));
			}
		} catch (IOException | RuntimeException e) {
			UpgraderTracker.LOGGER.error("Could not read {}, using defaults", path, e);
		}
		if (config.scoreboardObjective == null) {
			config.scoreboardObjective = "";
		}
		if (config.currencyItems == null) {
			config.currencyItems = new ArrayList<>();
		}
		return config;
	}
}
