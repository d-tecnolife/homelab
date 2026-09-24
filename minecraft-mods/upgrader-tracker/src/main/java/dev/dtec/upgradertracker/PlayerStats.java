package dev.dtec.upgradertracker;

/** Lifetime Upgrader totals for one player, in Upgrader value. */
public final class PlayerStats {
	public String name = "";
	public long spins;
	public long wins;
	public double staked;
	public double won;
	/** Lowest-chance win so far; 0 when the player has never won. */
	public double luckiestChance;
	public String luckiestItem = "";

	public double net() {
		return this.won - this.staked;
	}

	void record(Roll roll, boolean win) {
		this.spins++;
		this.staked += roll.stake();
		if (win) {
			this.wins++;
			this.won += roll.payout();
			if (this.luckiestChance == 0 || roll.chance() < this.luckiestChance) {
				this.luckiestChance = roll.chance();
				this.luckiestItem = roll.target().getHoverName().getString();
			}
		}
	}
}
