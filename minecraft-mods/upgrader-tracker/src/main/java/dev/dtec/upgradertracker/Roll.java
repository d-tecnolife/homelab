package dev.dtec.upgradertracker;

import net.minecraft.world.item.ItemStack;

/**
 * One Upgrader spin: what was staked, what it was rolled for, and both sides priced in Upgrader
 * value at the moment the spin started.
 */
public record Roll(ItemStack input, ItemStack target, double chance, double stake, double payout) {
}
