use crate::ERC1155NFT as NFT;
use crate::test::utils;
use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::aztec::oracle::random::random;

#[test]
unconstrained fn transfer_in_public() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_and_mint(false);

    // Transfer the NFT
    NFT::at(nft_contract_address).transfer_in_public(sender, recipient, token_id, U128::from_integer(3), 0).call(
        &mut env.public(),
    );

    env.advance_block_by(1);

    utils::assert_nft_balance(env, nft_contract_address, recipient, token_id, 3);
    utils::assert_nft_balance(env, nft_contract_address, sender, token_id, 7);
}

#[test]
unconstrained fn transfer_in_public_to_self() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_and_mint(false);

    // Transfer the NFT
    NFT::at(nft_contract_address).transfer_in_public(user, user, token_id, U128::from_integer(3), 0).call(&mut env.public());

    env.advance_block_by(1);

    utils::assert_nft_balance(env, nft_contract_address, user, token_id, 10);
}

#[test]
unconstrained fn transfer_in_public_on_behalf_of_other() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_and_mint(true);

    let transfer_in_public_from_call_interface =
        NFT::at(nft_contract_address).transfer_in_public(sender, recipient, token_id, U128::from_integer(3), 1);
    authwit_cheatcodes::add_public_authwit_from_call_interface(
        sender,
        recipient,
        transfer_in_public_from_call_interface,
    );
    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Transfer the NFT
    transfer_in_public_from_call_interface.call(&mut env.public());

    utils::assert_nft_balance(env, nft_contract_address, recipient, token_id, 3);
}

#[test(should_fail_with = "invalid nonce")]
unconstrained fn transfer_in_public_failure_on_behalf_of_self_non_zero_nonce() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_and_mint(false);

    // Try to transfer the NFT
    NFT::at(nft_contract_address).transfer_in_public(sender, recipient, token_id, U128::from_integer(3), random()).call(
        &mut env.public(),
    );
}

#[test(should_fail_with = "insufficient balance")]
unconstrained fn transfer_in_public_failure_on_insufficient_balance() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_and_mint(false);

    // Transfer the NFT
    NFT::at(nft_contract_address).transfer_in_public(user, user, token_id, U128::from_integer(30), 0).call(&mut env.public());
}

#[test(should_fail_with = "unauthorized")]
unconstrained fn transfer_in_public_failure_on_behalf_of_other_without_approval() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_and_mint(true);

    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Try to transfer tokens
    NFT::at(nft_contract_address).transfer_in_public(sender, recipient, token_id, U128::from_integer(3), 1).call(
        &mut env.public(),
    );
}

#[test(should_fail_with = "unauthorized")]
unconstrained fn transfer_in_public_failure_on_behalf_of_other_wrong_caller() {
    // Setup with account contracts. Slower since we actually deploy them, but needed for authwits.
    let (env, nft_contract_address, sender, recipient, token_id) =
        utils::setup_and_mint(/* with_account_contracts */ true);
    let transfer_in_public_from_call_interface =
        NFT::at(nft_contract_address).transfer_in_public(sender, recipient, token_id, U128::from_integer(3), 1);
    authwit_cheatcodes::add_public_authwit_from_call_interface(
        sender,
        sender,
        transfer_in_public_from_call_interface,
    );
    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Try to transfer tokens
    transfer_in_public_from_call_interface.call(&mut env.public());
}