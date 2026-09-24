package dev.dtec.upgradertracker;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** Per-player totals, kept as JSON in the world folder so they follow the world's backups. */
public final class StatsStore {
	private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

	private final Path path;
	private final Map<UUID, PlayerStats> players;

	private StatsStore(Path path, Map<UUID, PlayerStats> players) {
		this.path = path;
		this.players = players;
	}

	public static StatsStore load(Path path) {
		Map<UUID, PlayerStats> players = new LinkedHashMap<>();
		if (Files.exists(path)) {
			try {
				Map<UUID, PlayerStats> read = GSON.fromJson(Files.readString(path), new TypeToken<Map<UUID, PlayerStats>>() {}.getType());
				if (read != null) {
					players.putAll(read);
				}
			} catch (IOException | RuntimeException e) {
				// Never overwrite a file we failed to parse: keep it for a manual fix.
				UpgraderTracker.LOGGER.error("Could not read {}; stats start empty and the file is left untouched", path, e);
				return new StatsStore(path.resolveSibling(path.getFileName() + ".recovered"), players);
			}
		}
		return new StatsStore(path, players);
	}

	public PlayerStats get(UUID id, String name) {
		PlayerStats stats = this.players.computeIfAbsent(id, key -> new PlayerStats());
		stats.name = name;
		return stats;
	}

	public Optional<Map.Entry<UUID, PlayerStats>> byName(String name) {
		return this.players.entrySet().stream().filter(e -> e.getValue().name.equalsIgnoreCase(name)).findFirst();
	}

	public Map<UUID, PlayerStats> all() {
		return this.players;
	}

	public void save() {
		try {
			Path tmp = this.path.resolveSibling(this.path.getFileName() + ".tmp");
			Files.writeString(tmp, GSON.toJson(this.players));
			Files.move(tmp, this.path, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
		} catch (IOException e) {
			UpgraderTracker.LOGGER.error("Could not save {}", this.path, e);
		}
	}
}
