package dev.dtec.upgradertracker.mixin;

import dev.dtec.upgradertracker.Roll;
import dev.dtec.upgradertracker.UpgraderTracker;
import net.execheinz.upgrader.menu.UpgraderMenu;
import net.execheinz.upgrader.value.ItemValues;
import net.execheinz.upgrader.value.UpgradeOdds;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerInput;
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
import org.spongepowered.asm.mixin.injection.ModifyArg;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Upgrade Items decides a roll in startUpgrade() and pays it out in applyResult() once the wheel
 * stops (or the menu closes mid-spin). Capture the stake when a spin starts and report the
 * outcome when it resolves, so announcements never spoil the wheel. Also refuses spins staking
 * anything but the currency items and tells players who try to put something else in, and makes
 * the menu show the chance that is actually rolled.
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

	@Inject(method = "clicked", at = @At("HEAD"))
	private void upgraderTracker$explainRefusal(int slotId, int button, ContainerInput input, Player clicker, CallbackInfo ci) {
		if (this.isSpinning() || !(clicker instanceof ServerPlayer serverPlayer)) {
			return;
		}
		AbstractContainerMenu menu = (AbstractContainerMenu) (Object) this;
		// What the click would put into the input slot (slot 0).
		ItemStack offered = ItemStack.EMPTY;
		if (slotId == 0 && input == ContainerInput.PICKUP) {
			offered = menu.getCarried();
		} else if (slotId == 0 && input == ContainerInput.SWAP) {
			offered = clicker.getInventory().getItem(button);
		} else if (slotId > 0 && slotId < menu.slots.size() && input == ContainerInput.QUICK_MOVE) {
			offered = menu.slots.get(slotId).getItem();
		}
		if (!offered.isEmpty() && !UpgraderTracker.isCurrency(offered)) {
			UpgraderTracker.refuseStake(serverPlayer);
		}
	}

	/**
	 * syncToClient works the displayed chance out from values rounded to whole numbers, so a stack of
	 * 64 blocks worth 1.35 each showed 67.5% while rolling 50%. Send the chance startUpgrade rolls.
	 */
	@ModifyArg(method = "syncToClient", at = @At(value = "INVOKE",
		target = "Lnet/execheinz/upgrader/network/ClientboundUpgraderSyncPacket;<init>(Ljava/lang/String;IJJFI)V"), index = 4)
	private float upgraderTracker$exactChance(float rounded) {
		ItemStack stack = this.getInputStack();
		if (stack.isEmpty() || this.target == null) {
			return rounded;
		}
		return (float) UpgradeOdds.chance(this.player.level(), stack, this.target, this.clampCount(this.targetCount));
	}

	@Inject(method = "startUpgrade", at = @At("HEAD"), cancellable = true)
	private void upgraderTracker$stage(ServerPlayer serverPlayer, CallbackInfo ci) {
		this.upgraderTracker$staged = null;
		ItemStack stack = this.getInputStack();
		if (this.isSpinning() || stack.isEmpty() || this.target == null) {
			return;
		}
		if (!UpgraderTracker.isCurrency(stack)) {
			// The slot refuses these, but never spin one that got in some other way.
			UpgraderTracker.refuseStake(serverPlayer);
			ci.cancel();
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
