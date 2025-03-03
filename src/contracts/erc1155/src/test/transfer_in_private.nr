use crate::ERC1155NFT as NFT;
use crate::test::utils;
use dep::authwit::cheatcodes as authwit_cheatcodes;
use dep::aztec::test::helpers::cheatcodes;
use aztec::oracle::random::random;

#[test]
unconstrained fn transfer_in_private() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    // Transfer the NFT to the recipient
    NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(3), 0).call(
        &mut env.private(),
    );

    // Recipient should have the note in their private nfts
    utils::assert_private_nft_balance(nft_contract_address, sender, token_id, 7);
    utils::assert_private_nft_balance(nft_contract_address, recipient, token_id, 3);
}

#[test]
unconstrained fn transfer_in_private_to_self() {
    let (env, nft_contract_address, owner, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    // Transfer the NFT back to the owner
    NFT::at(nft_contract_address).transfer_in_private(owner, owner, token_id, U128::from_integer(3), 0).call(
        &mut env.private(),
    );

    // NFT balance should stay the same
    utils::assert_private_nft_balance(nft_contract_address, owner, token_id, 10);
}

#[test]
unconstrained fn transfer_in_private_to_non_deployed_account() {
    let (env, nft_contract_address, sender, _, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);
    let not_deployed = cheatcodes::create_account(999);

    // Transfer the NFT to the recipient
    NFT::at(nft_contract_address)
        .transfer_in_private(sender, not_deployed.address, token_id, U128::from_integer(3), 0)
        .call(&mut env.private());

    utils::assert_private_nft_balance(nft_contract_address, not_deployed.address, token_id, 3);
}

#[test]
unconstrained fn transfer_in_private_on_behalf_of_other() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(true, 10);

    // Transfer the NFT to the recipient
    let transfer_in_private_call_interface =
        NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(3), 1);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        sender,
        recipient,
        transfer_in_private_call_interface,
    );
}

#[test(should_fail_with = "insufficient balance")]
unconstrained fn transfer_in_private_failure_on_insufficient_balance() {
    let (env, nft_contract_address, sender, recipient, token_id) = utils::setup_mint_and_transfer_to_private(false, 10);

    NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(20), 0).call(
        &mut env.private(),
    );
}

#[test(should_fail_with = "invalid nonce")]
unconstrained fn transfer_in_private_failure_on_behalf_of_self_non_zero_nonce() {
    let (env, nft_contract_address, sender, recipient) = utils::setup(false);

    // We set random value for the token_id as the nonce check is before we use the value.
    let token_id = random();

    // Try transferring the NFT
    NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(3), 1).call(
        &mut env.private(),
    );
}

#[test(should_fail_with = "Authorization not found for message hash")]
unconstrained fn transfer_in_private_failure_on_behalf_of_other_without_approval() {
    let (env, nft_contract_address, sender, recipient) = utils::setup(true);

    // We set random value for the token_id as the nonce check is before we use the value.
    let token_id = random();

    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Try transferring the NFT
    NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(3), 1).call(
        &mut env.private(),
    );
}

#[test(should_fail_with = "Authorization not found for message hash")]
unconstrained fn transfer_in_private_failure_on_behalf_of_other_wrong_caller() {
    let (env, nft_contract_address, sender, recipient) = utils::setup(true);

    // We set random value for the token_id as the nonce check is before we use the value.
    let token_id = random();

    let transfer_in_private_from_call_interface =
        NFT::at(nft_contract_address).transfer_in_private(sender, recipient, token_id, U128::from_integer(3), 1);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        sender,
        sender,
        transfer_in_private_from_call_interface,
    );
    // Impersonate recipient to perform the call
    env.impersonate(recipient);
    // Try transferring the NFT
    transfer_in_private_from_call_interface.call(&mut env.private());
}