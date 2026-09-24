package dev.dtec.upgradertracker;

import java.util.Locale;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.ServerScoreboard;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.storage.LevelResource;
import net.minecraft.world.scores.Objective;
import net.minecraft.world.scores.ScoreHolder;
import net.minecraft.world.scores.criteria.ObjectiveCriteria;
import org.jetbrains.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class UpgraderTracker implements ModInitializer {
	public static final Logger LOGGER = LoggerFactory.getLogger("upgrader_tracker");

	static TrackerConfig config = new TrackerConfig();
	@Nullable static StatsStore stats;

	@Override
	public void onInitialize() {
		// Load before anything can tick a menu; the scoreboard only exists once the world has loaded.
		ServerLifecycleEvents.SERVER_STARTING.register(server -> {
			config = TrackerConfig.load();
			stats = StatsStore.load(server.getWorldPath(LevelResource.ROOT).resolve("upgrader_tracker.json"));
			LOGGER.info("Tracking Upgrader rolls for {} players; announcing wins under {}; floor jackpot cap {}", stats.all().size(), percent(config.announceBelowChance), whole(config.floorJackpotCap));
		});
		ServerLifecycleEvents.SERVER_STARTED.register(server -> {
			if (stats != null) {
				stats.all().values().forEach(player -> updateScore(server, player));
			}
		});
		ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
			if (stats != null) {
				stats.save();
			}
			stats = null;
		});
		CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> TrackerCommands.register(dispatcher));
	}

	/** Called by the mixin once a spin has resolved. */
	public static void onRoll(ServerPlayer player, Roll roll, boolean win) {
		MinecraftServer server = player.level().getServer();
		String name = player.getGameProfile().name();
		LOGGER.info("{} {} {} for {} at {} (stake {}, payout {})", name, win ? "won" : "lost",
			describe(roll.input()), describe(roll.target()), percent(roll.chance()), whole(roll.stake()), whole(win ? roll.payout() : 0));
		if (stats != null) {
			PlayerStats totals = stats.get(player.getUUID(), name);
			totals.record(roll, win);
			stats.save();
			updateScore(server, totals);
		}
		if (win && roll.chance() < config.announceBelowChance) {
			server.getPlayerList().broadcastSystemMessage(announcement(player, roll), false);
		}
	}

	private static Component announcement(ServerPlayer player, Roll roll) {
		return Component.empty()
			.append(Component.literal("✦ ").withStyle(ChatFormatting.GOLD))
			.append(player.getDisplayName().copy().withStyle(ChatFormatting.YELLOW))
			.append(Component.literal(" upgraded ").withStyle(ChatFormatting.WHITE))
			.append(stackName(roll.input()).withStyle(ChatFormatting.GRAY))
			.append(Component.literal(" into ").withStyle(ChatFormatting.WHITE))
			.append(stackName(roll.target()).withStyle(ChatFormatting.AQUA))
			.append(Component.literal(" at ").withStyle(ChatFormatting.WHITE))
			.append(Component.literal(percent(roll.chance())).withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD))
			.append(Component.literal(" odds!").withStyle(ChatFormatting.WHITE));
	}

	private static MutableComponent stackName(ItemStack stack) {
		MutableComponent name = stack.getHoverName().copy();
		return stack.getCount() > 1 ? Component.literal(stack.getCount() + "× ").append(name) : name;
	}

	private static String describe(ItemStack stack) {
		return stack.getCount() + "x " + stack.getHoverName().getString();
	}

	static void updateScore(MinecraftServer server, PlayerStats player) {
		String objectiveName = config.scoreboardObjective;
		if (objectiveName.isEmpty() || player.name.isEmpty()) {
			return;
		}
		ServerScoreboard scoreboard = server.getScoreboard();
		Objective objective = scoreboard.getObjective(objectiveName);
		if (objective == null) {
			objective = scoreboard.addObjective(objectiveName, ObjectiveCriteria.DUMMY, Component.literal("Upgrader net"),
				ObjectiveCriteria.RenderType.INTEGER, false, null);
		}
		scoreboard.getOrCreatePlayerScore(ScoreHolder.forNameOnly(player.name), objective).set(clampInt(player.net()));
	}

	static void clearScore(MinecraftServer server, String name) {
		Objective objective = config.scoreboardObjective.isEmpty() ? null : server.getScoreboard().getObjective(config.scoreboardObjective);
		if (objective != null) {
			server.getScoreboard().resetSinglePlayerScore(ScoreHolder.forNameOnly(name), objective);
		}
	}

	private static int clampInt(double value) {
		return (int) Math.max(Integer.MIN_VALUE, Math.min(Integer.MAX_VALUE, Math.round(value)));
	}

	static String percent(double chance) {
		return String.format(Locale.ROOT, chance < 0.01 ? "%.3f%%" : chance < 0.1 ? "%.2f%%" : "%.1f%%", chance * 100);
	}

	static String whole(double value) {
		return String.format(Locale.ROOT, "%,d", Math.round(value));
	}

	static String signed(double value) {
		long rounded = Math.round(value);
		return (rounded > 0 ? "+" : "") + String.format(Locale.ROOT, "%,d", rounded);
	}

	public static double floorJackpotCap() {
		return config.floorJackpotCap;
	}

	@Nullable
	static StatsStore stats() {
		return stats;
	}
}
