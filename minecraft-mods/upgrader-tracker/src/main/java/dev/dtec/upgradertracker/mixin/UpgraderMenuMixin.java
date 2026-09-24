package dev.dtec.upgradertracker.mixin;

import dev.dtec.upgradertracker.Roll;
import dev.dtec.upgradertracker.UpgraderTracker;
import net.execheinz.upgrader.menu.UpgraderMenu;
import net.execheinz.upgrader.value.ItemValues;
import net.execheinz.upgrader.value.UpgradeOdds;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Upgrade Items decides a roll in startUpgrade() and pays it out in applyResult() once the wheel
 * stops (or the menu closes mid-spin). Capture the stake when a spin starts and report the
 * outcome when it resolves, so announcements never spoil the wheel.
 */
@Mixin(value = UpgraderMenu.class, remap = false)
public abstract class UpgraderMenuMixin {
	@Shadow @Final private Player player;
	@Shadow @Nullable private Item target;
	@Shadow private int targetCount;
	@Shadow private boolean pendingWin;

	@Shadow public abstract boolean isSpinning();
	@Shadow public abstract ItemStack getInputStack();
	@Shadow private int clampCount(int count) { throw new AssertionError(); }

	@Unique @Nullable private Roll upgraderTracker$roll;
	@Unique @Nullable private Roll upgraderTracker$staged;

	@Inject(method = "startUpgrade", at = @At("HEAD"))
	private void upgraderTracker$stage(ServerPlayer serverPlayer, CallbackInfo ci) {
		this.upgraderTracker$staged = null;
		ItemStack stack = this.getInputStack();
		if (this.isSpinning() || stack.isEmpty() || this.target == null) {
			return;
		}
		// Same inputs startUpgrade feeds UpgradeOdds, taken before it runs.
		Level level = serverPlayer.level();
		int count = this.clampCount(this.targetCount);
		double chance = UpgradeOdds.chance(level, stack, this.target, count);
		double stake = ItemValues.stackValue(level, stack);
		double payout = ItemValues.unitValue(level, this.target) * count;
		this.upgraderTracker$staged = new Roll(stack.copy(), new ItemStack(this.target, count), chance, stake, payout);
	}

	@Inject(method = "startUpgrade", at = @At("RETURN"))
	private void upgraderTracker$started(ServerPlayer serverPlayer, CallbackInfo ci) {
		// startUpgrade bails out silently (cooldown, blacklist...); only a started spin counts.
		if (this.isSpinning()) {
			this.upgraderTracker$roll = this.upgraderTracker$staged;
		}
		this.upgraderTracker$staged = null;
	}

	@Inject(method = "applyResult", at = @At("HEAD"))
	private void upgraderTracker$resolved(CallbackInfo ci) {
		Roll roll = this.upgraderTracker$roll;
		this.upgraderTracker$roll = null;
		if (roll != null && this.player instanceof ServerPlayer serverPlayer && !this.getInputStack().isEmpty()) {
			UpgraderTracker.onRoll(serverPlayer, roll, this.pendingWin);
		}
	}
}
