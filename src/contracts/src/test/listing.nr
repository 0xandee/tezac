use crate::{NFT, types::listing_note::ListingNote};
use crate::test::utils;
use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::token_contract::Token;

#[test]
unconstrained fn list() {
    // Setup without account contracts. We are not using authwits here, so dummy accounts are enough
    let (env, _, nft_contract_address, buyer, seller, token_id, amount) =
        utils::setup_mint_and_transfer_to_private(/* with_account_contracts */ false);

    // Transfer the NFT to the buyer so the seller can purchase it
    NFT::at(nft_contract_address).transfer_in_private(buyer, seller, token_id, 0).call(
        &mut env.private(),
    );
    env.impersonate(seller);
    // List the NFT purchasable by buyer for amount token
    NFT::at(nft_contract_address).list(token_id, amount, buyer).call(
        &mut env.private(),
    );

    // Seller and buyer should have the note in their private listings
    utils::assert_owns_private_listing(nft_contract_address, ListingNote::new(token_id, seller, seller, buyer, amount));
    utils::assert_owns_private_listing(nft_contract_address, ListingNote::new(token_id, buyer, seller, buyer, amount));
}

#[test]
unconstrained fn cancel_listing() {
    // Setup without account contracts. We are not using authwits here, so dummy accounts are enough
    let (env, _, nft_contract_address, buyer, seller, token_id, amount) =
        utils::setup_mint_transfer_to_private_and_list(/* with_account_contracts */ false);

    env.impersonate(seller);
    // Cancel the listing
    NFT::at(nft_contract_address).cancel_listing(token_id).call(&mut env.private());

    // Seller and buyer should no longer have the notes in their private listings
    utils::assert_doesnt_own_private_listing(nft_contract_address, ListingNote::new(token_id, seller, seller, buyer, amount));
    utils::assert_doesnt_own_private_listing(nft_contract_address, ListingNote::new(token_id, buyer, seller, buyer, amount));
}

#[test]
unconstrained fn purchase() {
    // Setup with account contracts. Slower since we actually deploy them, but needed for authwits.
    let (env, token_contract_address, nft_contract_address, buyer, seller, token_id, amount) =
        utils::setup_mint_transfer_to_private_and_list(/* with_account_contracts */ true);

    // Seller should own the NFT and zero token balance, buyer should have listing price amount of token balance
    utils::assert_owns_private_nft(nft_contract_address, seller, token_id);
    utils::check_private_balance(token_contract_address, seller, U128::zero());
    utils::check_private_balance(token_contract_address, buyer, amount);

    // Approve the NFT contract to spend buyer token balance
    let transfer_in_private_call_interface =
        Token::at(token_contract_address).transfer_in_private(buyer, seller, amount, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        buyer,
        nft_contract_address,
        transfer_in_private_call_interface,
    );
    // Purchase the listing
    NFT::at(nft_contract_address).purchase(token_id, 0).call(&mut env.private());

    // Buyer should own the NFT and zero balance, seller should have listing price amount of token balance
    utils::assert_owns_private_nft(nft_contract_address, buyer, token_id);
    utils::check_private_balance(token_contract_address, seller, amount);
    utils::check_private_balance(token_contract_address, buyer, U128::zero());
}
