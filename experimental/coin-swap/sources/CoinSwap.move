module CoinSwap::CoinSwap {
    use std::signer;
    use std::error;
    use BasicCoin::BasicCoin;
    use CoinSwap::PoolToken;
    use std::debug;



    const ECOINSWAP_ADDRESS: u64 = 0;
    const EPOOL: u64 = 0;

    struct LiquidityPool<phantom CoinType1, phantom CoinType2> has key {
        coin1: u64,
        coin2: u64,
        share: u64,// we can define the share !? 
    }

    // Added drop ability to CoinType
    public fun create_pool<CoinType1: drop + copy, CoinType2: drop + copy>(
        coinswap: &signer,
        requester: &signer,
        coin1: u64,
        coin2: u64,
        share: u64,
        witness1: CoinType1,
        witness2: CoinType2
    ) {
        // Create a pool at @CoinSwap.
        // TODO: If the balance is already published, this step should be skipped rather than abort.
        // TODO: Alternatively, `struct LiquidityPool` could be refactored to actually hold the coin (e.g., coin1: CoinType1).

        // SO IMPORTANT!!!!!!
        // Only `publish_balance` doesn't work! VMError: MISSING_DATA 
        // when calling borrow_global<Balance<CoinType>>(owner).coin.value at BasicCoin::balance_of
        BasicCoin::publish_balance<CoinType1>(coinswap);
        BasicCoin::publish_balance<CoinType1>(requester);
        BasicCoin::mint<CoinType1>(signer::address_of(requester), coin1, witness1);
        BasicCoin::publish_balance<CoinType2>(coinswap);
        BasicCoin::publish_balance<CoinType2>(requester);
        BasicCoin::mint<CoinType2>(signer::address_of(requester), coin2, witness2);

        assert!(signer::address_of(coinswap) == @CoinSwap, error::invalid_argument(ECOINSWAP_ADDRESS));
        assert!(!exists<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap)), error::already_exists(EPOOL));
        debug::print(&coin1);
        
        move_to(coinswap, LiquidityPool<CoinType1, CoinType2>{coin1, coin2, share});
        debug::print(&coin2);

        // Transfer the initial liquidity of CoinType1 and CoinType2 to the pool under @CoinSwap.

        // CHECK: move 2 Coins from requestor to coinswap
        // requester needs to have enough coin1?
        BasicCoin::transfer<CoinType1>(requester, signer::address_of(coinswap), coin1, witness1);
        BasicCoin::transfer<CoinType2>(requester, signer::address_of(coinswap), coin2, witness2);
        debug::print(&coin1);

        // Mint PoolToken and deposit it in the account of requester.
        PoolToken::setup_and_mint<CoinType1, CoinType2>(requester, share);
    }

    fun get_input_price(input_amount: u64, input_reserve: u64, output_reserve: u64): u64 {
        let input_amount_with_fee = input_amount * 997;
        let numerator = input_amount_with_fee * output_reserve;
        let denominator = (input_reserve * 1000) + input_amount_with_fee;
        numerator / denominator
    }

    public fun coin1_to_coin2_swap_input<CoinType1: drop, CoinType2: drop>(
        coinswap: &signer,
        requester: &signer,
        coin1: u64,
        witness1: CoinType1,
        witness2: CoinType2
    ) acquires LiquidityPool {
        assert!(signer::address_of(coinswap) == @CoinSwap, error::invalid_argument(ECOINSWAP_ADDRESS));
        assert!(exists<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap)), error::not_found(EPOOL));
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(signer::address_of(coinswap));
        let coin2 = get_input_price(coin1, pool.coin1, pool.coin2);
        pool.coin1 = pool.coin1 + coin1;
        pool.coin2 = pool.coin2 - coin2;

        BasicCoin::transfer<CoinType1>(requester, signer::address_of(coinswap), coin1, witness1);
        BasicCoin::transfer<CoinType2>(coinswap, signer::address_of(requester), coin2, witness2);
    }

    public fun add_liquidity<CoinType1: drop, CoinType2: drop>(
        account: &signer,
        coin1: u64,
        coin2: u64,
        witness1: CoinType1,
        witness2: CoinType2,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(@CoinSwap);

        let coin1_added = coin1;
        let share_minted = (coin1_added * pool.share) / pool.coin1;
        let coin2_added = (share_minted * pool.coin2) / pool.share;

        pool.coin1 = pool.coin1 + coin1_added;
        pool.coin2 = pool.coin2 + coin2_added;
        pool.share = pool.share + share_minted;

        BasicCoin::transfer<CoinType1>(account, @CoinSwap, coin1, witness1);
        BasicCoin::transfer<CoinType2>(account, @CoinSwap, coin2, witness2);
        PoolToken::mint<CoinType1, CoinType2>(signer::address_of(account), share_minted)
    }

    public fun remove_liquidity<CoinType1: drop, CoinType2: drop>(
        coinswap: &signer,
        requester: &signer,
        share: u64,
        witness1: CoinType1,
        witness2: CoinType2,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType1, CoinType2>>(@CoinSwap);

        let coin1_removed = (pool.coin1 * share) / pool.share;
        let coin2_removed = (pool.coin2 * share) / pool.share;

        pool.coin1 = pool.coin1 - coin1_removed;
        pool.coin2 = pool.coin2 - coin2_removed;
        pool.share = pool.share - share;

        BasicCoin::transfer<CoinType1>(coinswap, signer::address_of(requester), coin1_removed, witness1);
        BasicCoin::transfer<CoinType2>(coinswap, signer::address_of(requester), coin2_removed, witness2);
        PoolToken::burn<CoinType1, CoinType2>(signer::address_of(requester), share)
    }
}

module CoinSwap::MyCoinSwap {
    use std::signer;
    // use std::error;
    use std::debug;
    use BasicCoin::BasicCoin;
    use CoinSwap::CoinSwap;

    use GoldCoin::GoldCoin;
    use SilverCoin::SilverCoin;

    struct GoldCoin has drop, copy {}
    struct SilverCoin has drop, copy {} 

    #[test(account = @0x01)]
    fun test_coin_type(account: &signer) {
        GoldCoin::setup_and_mint(account, 100);// account, amount
        SilverCoin::setup_and_mint(account, 200);// account, amount    
        let gold_bal = BasicCoin::balance_of<GoldCoin>(signer::address_of(account));
        debug::print(&gold_bal);
    }

    #[test(coinswap = @CoinSwap, requestor = @0x02)]
    fun test_create_pool(coinswap:&signer, requestor: &signer) {
        test_coin_type(requestor);
        let gold_bal = BasicCoin::balance_of<GoldCoin>(signer::address_of(requestor));
        debug::print(&gold_bal);
        assert!(gold_bal == 100, 1);

        // let goldCoin = GoldCoin(goldcoin_addr);
        // let silverCoin = SilverCoin(silvercoin_addr);
        let coin1_amount = 10;
        let coin2_amount = 20;
        let share = 1;

        CoinSwap::create_pool<GoldCoin, SilverCoin>(
            coinswap,
            requestor,
            coin1_amount,
            coin2_amount,
            share,
            GoldCoin{},
            SilverCoin{});
    }
}
