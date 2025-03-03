use crate::{ERC1155NFT as NFT, test::utils, types::uint_note::UintNote};
use dep::aztec::{
    oracle::random::random,
    prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use std::test::OracleMock;

/// Internal orchestration means that the calls to `prepare_private_balance_increase`
/// and `finalize_transfer_to_private` are done by the NFT contract itself.
#[test]
unconstrained fn transfer_to_private_internal_orchestration() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 2);

    // User should have the note in their private nfts
    utils::assert_private_nft_balance(nft_contract_address, user, token_id, 2);

    // get the public nft balance
    utils::assert_nft_balance(env, nft_contract_address, user, token_id, 8);
}

/// External orchestration means that the calls to prepare and finalize are not done by the NFT contract. This flow
/// will typically be used by a DEX.
#[test]
unconstrained fn transfer_to_private_external_orchestration() {
    let (env, nft_contract_address, user, recipient, token_id, amount) = utils::setup_and_mint(false);
    utils::assert_nft_balance(env, nft_contract_address, user, token_id, 10);
    utils::assert_nft_balance(env, nft_contract_address, recipient, token_id, 0);

    let note_randomness = random();

    // We mock the Oracle to return the note randomness such that later on we can manually add the note
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    // We prepare the transfer
    let hiding_point_slot: Field = NFT::at(nft_contract_address)
        .prepare_private_balance_increase(token_id, recipient)
        .call(&mut env.private());
    
    let private_balance = utils::get_private_nft_balance(nft_contract_address, recipient, token_id);
    let new_amount = U128::from_integer(3);

    env.impersonate(user);

    // Finalize the transfer of the NFT (message sender owns the NFT in public)
    NFT::at(nft_contract_address).finalize_transfer_to_private(token_id, new_amount, private_balance + new_amount, hiding_point_slot).call(
        &mut env.public(),
    );

    env.advance_block_by(1);

    // Recipient should have the note in their private nfts
    utils::assert_private_nft_balance(nft_contract_address, recipient, token_id, 3);

    // get the public nft balance
    utils::assert_nft_balance(env, nft_contract_address, user, token_id, 7);
}

#[test(should_fail_with = "transfer not prepared")]
unconstrained fn transfer_to_private_transfer_not_prepared() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_and_mint(false);

    // Transfer was not prepared so we can use random value for the hiding point slot
    let hiding_point_slot = random();

    env.impersonate(user);

    // Try finalizing the transfer without preparing it
    NFT::at(nft_contract_address).finalize_transfer_to_private(token_id, U128::from_integer(3), U128::from_integer(3), hiding_point_slot).call(
        &mut env.public(),
    );
}

#[test(should_fail_with = "insufficient balance")]
unconstrained fn transfer_to_private_failure_not_an_owner() {
    let (env, nft_contract_address, user, recipient, token_id) = utils::setup_and_mint(false);

    // (For this specific test we could set a random value for the commitment and not do the call to `prepare...`
    // as the NFT owner check is before we use the value but that would made the test less robust against changes
    // in the contract.)
    let hiding_point_slot: Field = NFT::at(nft_contract_address)
        .prepare_private_balance_increase(token_id, recipient)
        .call(&mut env.private());

    env.impersonate(user);

    NFT::at(nft_contract_address).finalize_transfer_to_private(token_id, U128::from_integer(12), U128::from_integer(12), hiding_point_slot).call(
        &mut env.public(),
    );
}