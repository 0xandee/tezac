use crate::{NFT, types::erc1155_nft_note::ERC1155NFTNote};
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use std::test::OracleMock;

pub unconstrained fn setup(with_account_contracts: bool) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let (owner, recipient) = if with_account_contracts {
        let owner = env.create_account_contract(1);
        let recipient = env.create_account_contract(2);
        (owner, recipient)
    } else {
        let owner = env.create_account(1);
        let recipient = env.create_account(2);
        (owner, recipient)
    };

    env.impersonate(owner);

    // Deploy NFT contract
    let initializer_call_interface = NFT::interface().constructor(
        owner,
        "TestNFT000000000000000000000000",
        "TN00000000000000000000000000000",
    );
    let nft_contract =
        env.deploy_self("NFT").with_public_void_initializer(initializer_call_interface);
    let nft_contract_address = nft_contract.to_address();
    env.advance_block_by(1);
    (&mut env, nft_contract_address, owner, recipient)
}

pub unconstrained fn setup_and_mint(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, Field) {
    // Setup
    let (env, nft_contract_address, owner, recipient) = setup(with_account_contracts);
    let minted_token_id = 615;

    NFT::at(nft_contract_address).mint(owner, minted_token_id, U128::from_integer(10)).call(&mut env.public());
    env.advance_block_by(1);

    (env, nft_contract_address, owner, recipient, minted_token_id)
}

pub unconstrained fn setup_mint_and_transfer_to_private(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, Field) {
    let (env, nft_contract_address, owner, recipient, minted_token_id) =
        setup_and_mint(with_account_contracts);

    let note_randomness = random();

    // We mock the Oracle to return the note randomness such that later on we can manually add the note
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    // Transfer the public NFT to private.
    NFT::at(nft_contract_address).transfer_to_private(owner, minted_token_id, U128::from_integer(10)).call(
        &mut env.private(),
    );

    env.advance_block_by(1);

    (env, nft_contract_address, owner, recipient, minted_token_id)
}

pub unconstrained fn get_nft_total_supply(nft_contract_address: AztecAddress, token_id: Field) -> U128 {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(nft_contract_address);
    let block_number = get_block_number();

    let total_supply_slot = NFT::storage_layout().nft_total_supply.slot;
    let nft_slot = derive_storage_slot_in_map(total_supply_slot, token_id);
    let total_supply: U128 = storage_read(nft_contract_address, nft_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);

    total_supply
}

pub unconstrained fn assert_nft_balance(
    env: &mut TestEnvironment,
    nft_contract_address: AztecAddress,
    owner: AztecAddress,
    token_id: Field,
    balance: U128,
) {
    let obtained_balance = NFT::at(nft_contract_address).balance_of(owner, token_id).view(&mut env.public());

    assert(balance == obtained_balance, "Incorrect NFT balance");
}

pub unconstrained fn assert_private_nft_balance(
    nft_contract_address: AztecAddress,
    owner: AztecAddress,
    token_id: Field,
    balance: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(nft_contract_address);

    // Direct call to unconstrained
    let (private_nfts, _) = NFT::get_private_nfts(owner, 0);

    let mut nft_found = false;
    for obtained_nft in private_nfts {
        if (obtained_nft.token_id == token_id) & (obtained_nft.amount == balance) {
            nft_found = true;
        }
    }

    cheatcodes::set_contract_address(current_contract_address);

    assert(nft_found, "Incorrect private NFT balance");
}