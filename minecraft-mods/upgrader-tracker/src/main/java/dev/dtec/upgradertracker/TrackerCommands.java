package dev.dtec.upgradertracker;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.suggestion.SuggestionProvider;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.ToDoubleFunction;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;

/**
 * /upgrader stats [player]  - lifetime totals (anyone)
 * /upgrader top [net|staked|won|wins|spins] - top ten (anyone)
 * /upgrader reset <player|all> - wipe totals (ops)
 */
final class TrackerCommands {
	private static final List<String> BOARDS = List.of("net", "staked", "won", "wins", "spins");

	private static final SuggestionProvider<CommandSourceStack> KNOWN_PLAYERS = (ctx, builder) -> {
		StatsStore stats = UpgraderTracker.stats();
		return SharedSuggestionProvider.suggest(stats == null ? List.of() : stats.all().values().stream().map(p -> p.name).toList(), builder);
	};

	private TrackerCommands() {
	}

	static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
		dispatcher.register(Commands.literal("upgrader")
			.then(Commands.literal("stats")
				.executes(ctx -> showSelf(ctx))
				.then(Commands.argument("player", StringArgumentType.word()).suggests(KNOWN_PLAYERS)
					.executes(ctx -> show(ctx, StringArgumentType.getString(ctx, "player")))))
			.then(Commands.literal("top")
				.executes(ctx -> top(ctx, "net"))
				.then(Commands.argument("by", StringArgumentType.word())
					.suggests((ctx, builder) -> SharedSuggestionProvider.suggest(BOARDS, builder))
					.executes(ctx -> top(ctx, StringArgumentType.getString(ctx, "by")))))
			.then(Commands.literal("reset")
				.requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS))
				.then(Commands.argument("player", StringArgumentType.word()).suggests(KNOWN_PLAYERS)
					.executes(ctx -> reset(ctx, StringArgumentType.getString(ctx, "player"))))));
	}

	private static int showSelf(CommandContext<CommandSourceStack> ctx) {
		ServerPlayer player = ctx.getSource().getPlayer();
		if (player == null) {
			ctx.getSource().sendFailure(Component.literal("Name a player: /upgrader stats <player>"));
			return 0;
		}
		return show(ctx, player.getGameProfile().name());
	}

	private static int show(CommandContext<CommandSourceStack> ctx, String name) {
		StatsStore stats = UpgraderTracker.stats();
		Map.Entry<UUID, PlayerStats> entry = stats == null ? null : stats.byName(name).orElse(null);
		if (entry == null) {
			ctx.getSource().sendFailure(Component.literal(name + " hasn't used the Upgrader yet."));
			return 0;
		}
		PlayerStats p = entry.getValue();
		double winRate = p.spins == 0 ? 0 : (double) p.wins / p.spins;
		double returned = p.staked == 0 ? 0 : p.net() / p.staked;
		CommandSourceStack source = ctx.getSource();
		source.sendSuccess(() -> Component.literal("Upgrader stats for " + p.name).withStyle(ChatFormatting.GOLD), false);
		source.sendSuccess(() -> Component.literal(p.spins + " spins, " + p.wins + " wins (" + UpgraderTracker.percent(winRate) + ")"), false);
		source.sendSuccess(() -> Component.literal("Staked " + UpgraderTracker.whole(p.staked) + ", won " + UpgraderTracker.whole(p.won) + ", net ")
			.append(Component.literal(UpgraderTracker.signed(p.net()) + " (" + UpgraderTracker.signed(returned * 100) + "%)")
				.withStyle(p.net() >= 0 ? ChatFormatting.GREEN : ChatFormatting.RED)), false);
		if (p.luckiestChance > 0) {
			source.sendSuccess(() -> Component.literal("Luckiest win: " + p.luckiestItem + " at " + UpgraderTracker.percent(p.luckiestChance)), false);
		}
		return 1;
	}

	private static int top(CommandContext<CommandSourceStack> ctx, String by) {
		ToDoubleFunction<PlayerStats> key = switch (by) {
			case "net" -> PlayerStats::net;
			case "staked" -> p -> p.staked;
			case "won" -> p -> p.won;
			case "wins" -> p -> p.wins;
			case "spins" -> p -> p.spins;
			default -> null;
		};
		if (key == null) {
			ctx.getSource().sendFailure(Component.literal("Rank by one of: " + String.join(", ", BOARDS)));
			return 0;
		}
		StatsStore stats = UpgraderTracker.stats();
		List<PlayerStats> ranked = stats == null ? List.of() : stats.all().values().stream()
			.filter(p -> p.spins > 0)
			.sorted(Comparator.comparingDouble(key).reversed())
			.limit(10)
			.toList();
		if (ranked.isEmpty()) {
			ctx.getSource().sendFailure(Component.literal("Nobody has used the Upgrader yet."));
			return 0;
		}
		ctx.getSource().sendSuccess(() -> Component.literal("Upgrader top " + by).withStyle(ChatFormatting.GOLD), false);
		for (int i = 0; i < ranked.size(); i++) {
			PlayerStats p = ranked.get(i);
			double value = key.applyAsDouble(p);
			String shown = by.equals("net") ? UpgraderTracker.signed(value) : UpgraderTracker.whole(value);
			String line = (i + 1) + ". " + p.name + "  " + shown;
			ctx.getSource().sendSuccess(() -> Component.literal(line), false);
		}
		return ranked.size();
	}

	private static int reset(CommandContext<CommandSourceStack> ctx, String name) {
		StatsStore stats = UpgraderTracker.stats();
		if (stats == null) {
			return 0;
		}
		List<Map.Entry<UUID, PlayerStats>> targets = name.equalsIgnoreCase("all")
			? List.copyOf(stats.all().entrySet())
			: stats.byName(name).map(List::of).orElse(List.of());
		if (targets.isEmpty()) {
			ctx.getSource().sendFailure(Component.literal(name + " has no Upgrader stats."));
			return 0;
		}
		for (Map.Entry<UUID, PlayerStats> entry : targets) {
			UpgraderTracker.clearScore(ctx.getSource().getServer(), entry.getValue().name);
			stats.all().remove(entry.getKey());
		}
		stats.save();
		ctx.getSource().sendSuccess(() -> Component.literal("Reset Upgrader stats for " + targets.size() + " player(s)."), true);
		return targets.size();
	}
}
