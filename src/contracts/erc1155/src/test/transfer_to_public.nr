use crate::ERC1155NFT as NFT;
use crate::test::utils;
use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::aztec::oracle::random::random;

#[test]
unconstrained fn transfer_to_public() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    NFT::at(nft_contract_address).transfer_to_public(sender, recipient, token_id, U128::from_integer(4), 0).call(
        &mut env.private(),
    );

    utils::assert_private_nft_balance(nft_contract_address, sender, token_id, 6);
    utils::assert_nft_balance(env, nft_contract_address, recipient, token_id, 4);
}

#[test]
unconstrained fn transfer_to_public_to_self() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    NFT::at(nft_contract_address).transfer_to_public(user, user, token_id, U128::from_integer(4), 0).call(
        &mut env.private(),
    );

    utils::assert_private_nft_balance(nft_contract_address, user, token_id, 6);
    utils::assert_nft_balance(env, nft_contract_address, user, token_id, 4);
}

#[test]
unconstrained fn transfer_to_public_on_behalf_of_other() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(true, 10);

    let transfer_to_public_call_interface =
        NFT::at(nft_contract_address).transfer_to_public(sender, recipient, token_id, U128::from_integer(4), 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        sender,
        recipient,
        transfer_to_public_call_interface,
    );
    // Impersonate recipient
    env.impersonate(recipient);
    // transfer_to_public the NFT
    transfer_to_public_call_interface.call(&mut env.private());

    utils::assert_nft_balance(env, nft_contract_address, recipient, token_id, 4);
}

#[test(should_fail_with = "insufficient balance")]
unconstrained fn transfer_to_public_failure_insufficient_balance() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    NFT::at(nft_contract_address).transfer_to_public(user, user, token_id, U128::from_integer(20), 0).call(
        &mut env.private(),
    );
}

#[test(should_fail_with = "invalid nonce")]
unconstrained fn transfer_to_public_failure_on_behalf_of_self_non_zero_nonce() {
    let (env, nft_contract_address, user, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    NFT::at(nft_contract_address).transfer_to_public(user, user, token_id, U128::from_integer(4), random()).call(
        &mut env.private(),
    );
}

#[test(should_fail_with = "Authorization not found for message hash")]
unconstrained fn transfer_to_public_failure_on_behalf_of_other_invalid_designated_caller() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(true, 10);

    let transfer_to_public_call_interface =
        NFT::at(nft_contract_address).transfer_to_public(sender, recipient, token_id, U128::from_integer(4), 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        sender,
        sender,
        transfer_to_public_call_interface,
    );
    // Impersonate recipient
    env.impersonate(recipient);
    // transfer_to_public the NFT
    transfer_to_public_call_interface.call(&mut env.private());
}

#[test(should_fail_with = "Authorization not found for message hash")]
unconstrained fn transfer_to_public_failure_on_behalf_of_other_no_approval() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(true, 10);

    // Impersonate recipient
    env.impersonate(recipient);
    // transfer_to_public the NFT
    NFT::at(nft_contract_address).transfer_to_public(sender, recipient, token_id, U128::from_integer(4), 0).call(
        &mut env.private(),
    );
}