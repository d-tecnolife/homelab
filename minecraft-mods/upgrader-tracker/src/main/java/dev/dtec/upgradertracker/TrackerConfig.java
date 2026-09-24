package dev.dtec.upgradertracker;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import net.fabricmc.loader.api.FabricLoader;

/** config/upgrader-tracker.json; written with defaults when missing. */
public final class TrackerConfig {
	private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

	/** Wins at a chance strictly below this (0..1) are announced to the whole server. */
	public double announceBelowChance = 0.2;
	/** Scoreboard objective mirroring each player's net result; empty disables it. */
	public String scoreboardObjective = "upgrader_net";

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
		return config;
	}
}
