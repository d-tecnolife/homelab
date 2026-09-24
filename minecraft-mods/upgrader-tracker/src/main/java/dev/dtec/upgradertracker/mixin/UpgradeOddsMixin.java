package dev.dtec.upgradertracker.mixin;

import dev.dtec.upgradertracker.UpgraderTracker;
import net.execheinz.upgrader.UpgraderConfig;
import net.execheinz.upgrader.value.UpgradeOdds;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Upgrade Items lifts every roll to at least minChance, so a 1-cobblestone stake can be aimed at
 * any jackpot. Keep that floor for targets up to floorJackpotCap and shrink it in proportion above,
 * so a floor-propped roll is never worth more on average than one at the cap. Rolls whose fair
 * chance is above the floor are untouched. Both the roll and the chance shown in the menu use this.
 */
@Mixin(value = UpgradeOdds.class, remap = false)
public abstract class UpgradeOddsMixin {
	@Inject(method = "chance(DD)D", at = @At("HEAD"), cancellable = true)
	private static void upgraderTracker$scaleFloor(double inputValue, double targetValue, CallbackInfoReturnable<Double> cir) {
		double cap = UpgraderTracker.floorJackpotCap();
		if (cap <= 0 || inputValue <= 0 || targetValue <= cap) {
			return;
		}
		double raw = UpgraderConfig.houseEdge * inputValue / targetValue;
		double floor = UpgraderConfig.minChance * cap / targetValue;
		cir.setReturnValue(Math.max(floor, Math.min(UpgraderConfig.maxChance, raw)));
	}
}
