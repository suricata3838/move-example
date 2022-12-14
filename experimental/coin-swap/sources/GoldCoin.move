module GoldCoin::GoldCoin {
    use std::signer;
    use BasicCoin::BasicCoin;

    struct GoldCoin has drop, copy {}

    public fun setup_and_mint(account: &signer, amount: u64) {
        BasicCoin::publish_balance<GoldCoin>(account);
        BasicCoin::mint<GoldCoin>(signer::address_of(account), amount, GoldCoin{});
        
    }

    public fun balance_of(owner: address) {
        BasicCoin::balance_of<GoldCoin>(owner);
    }

    public fun transfer(from: &signer, to: address, amount: u64) {
        BasicCoin::transfer<GoldCoin>(from, to, amount, GoldCoin {});
    }
}
