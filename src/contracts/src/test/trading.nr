use crate::NFT;
use crate::test::utils;
use dep::aztec::{
    context::PrivateContext,
    note::note_header::NoteHeader,
    oracle::random::random,
    test::helpers::test_environment::TestEnvironment,
    prelude::AztecAddress,
};

// Helper function to setup NFT and payment token for trading tests
unconstrained fn setup_trading() -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, Field) {
    let (env, nft_contract_address, owner, buyer) = utils::setup(false);
    let token_id = 615;

    // Mint private NFT to owner
    NFT::at(nft_contract_address)
        .private_mint(owner, token_id)
        .call(&mut env.private());

    env.advance_block_by(1);

    // Verify NFT was minted
    utils::assert_owns_private_nft(nft_contract_address, owner, token_id);

    // Setup mock payment token balance for buyer
    // let payment_token = Token::at(storage.payment_token.read()).payment_token.read();
    // let mock_balance = 10000; // Large enough for test purchases

    (env, nft_contract_address, owner, buyer, token_id)
}

#[test(should_fail_with = "Price must be positive")]
unconstrained fn create_listing_failure_zero_price() {
    let (env, nft_contract_address, owner, _, token_id) = utils::setup_for_trading();

    // Try to create listing with zero price
    NFT::at(nft_contract_address)
        .create_listing(token_id, 0)
        .call(&mut env.private());
}

#[test(should_fail_with = "Seller does not own this NFT")]
unconstrained fn create_listing_failure_not_owner() {
    let (env, nft_contract_address, _, non_owner, token_id) = utils::setup_for_trading();
    
    // Try to list NFT as non-owner
    env.impersonate(non_owner);
    NFT::at(nft_contract_address)
        .create_listing(token_id, 1000)
        .call(&mut env.private());
}

#[test(should_fail_with = "Insufficient funds")]
unconstrained fn purchase_listing_failure_price_too_low() {
    let (env, nft_contract_address, seller, buyer, token_id) = utils::setup_for_trading();
    let list_price = 1000;
    let bid_price = 900;

    // Create listing
    NFT::at(nft_contract_address)
        .create_listing(token_id, list_price)
        .call(&mut env.private());

    env.advance_block_by(1);

    // Try to purchase with lower price
    env.impersonate(buyer);
    NFT::at(nft_contract_address)
        .purchase_listing(seller, token_id, bid_price)
        .call(&mut env.private());
}

#[test(should_fail_with = "Listing not found")]
unconstrained fn purchase_listing_failure_non_existent() {
    let (env, nft_contract_address, seller, buyer) = utils::setup(false);
    let token_id = 615; // Non-existent `                                                                                                                                                                                                                                                                                                                                                                       `                                                                                                                                                                               `listing

    // Try to purchase non-existent listing
    env.impersonate(buyer);
    NFT::at(nft_contract_address)
        .purchase_listing(seller, token_id, 1000)
        .call(&mut env.private());
}

#[test(should_fail_with = "Listing not found")]
unconstrained fn cancel_listing_failure_not_owner() {
    let (env, nft_contract_address, owner, non_owner, token_id) = utils::setup_for_trading();
    
    // Create listing as owner
    NFT::at(nft_contract_address)
        .create_listing(token_id, 1000)
        .call(&mut env.private());

    env.advance_block_by(1);

    // Try to cancel as non-owner
    env.impersonate(non_owner);
    NFT::at(nft_contract_address)
        .cancel_listing(token_id)
        .call(&mut env.private());
}
