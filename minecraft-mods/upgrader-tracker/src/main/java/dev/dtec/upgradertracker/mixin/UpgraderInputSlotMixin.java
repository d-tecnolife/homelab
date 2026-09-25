package dev.dtec.upgradertracker.mixin;

import dev.dtec.upgradertracker.UpgraderTracker;
import net.minecraft.world.item.ItemStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * The Upgrader's input slot (an anonymous Slot in UpgraderMenu) only takes the currency items, so
 * clicks, shift-clicks and hotbar swaps of anything else leave the slot empty. Clients don't run
 * this, so they may briefly show a refused item in the slot until the server corrects it.
 */
@Mixin(targets = "net.execheinz.upgrader.menu.UpgraderMenu$2", remap = false)
public abstract class UpgraderInputSlotMixin {
	@Inject(method = "mayPlace", at = @At("HEAD"), cancellable = true)
	private void upgraderTracker$currencyOnly(ItemStack stack, CallbackInfoReturnable<Boolean> cir) {
		if (!UpgraderTracker.isCurrency(stack)) {
			cir.setReturnValue(false);
		}
	}
}
