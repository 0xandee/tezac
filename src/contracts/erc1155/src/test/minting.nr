use crate::NFT;
use crate::test::utils;

#[test]
unconstrained fn mint_success() {
    let (env, nft_contract_address, owner, _) = utils::setup(false);

    let token_id = 10000;
    let amount = U128::from_integer(10);
    NFT::at(nft_contract_address).mint(owner, token_id, amount).call(&mut env.public());

    env.advance_block_by(1);

    utils::assert_nft_balance(env, nft_contract_address, owner, token_id, amount);
}

#[test]
unconstrained fn mint_failures() {
    let (env, nft_contract_address, owner, recipient) = utils::setup(false);

    // MINTING NFT WITH AMOUNT 0
    let token_id = 10000;
    let mint_call_interface = NFT::at(nft_contract_address).mint(owner, token_id, U128::from_integer(0));
    env.impersonate(owner);
    env.assert_public_call_fails(mint_call_interface);

    // MINTING NFT WITH TOKEN ID 0
    let mint_call_interface = NFT::at(nft_contract_address).mint(owner, 0, U128::from_integer(10)); 
    env.assert_public_call_fails(mint_call_interface);
}