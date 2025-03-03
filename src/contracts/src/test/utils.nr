use crate::{NFT, types::listing_note::ListingNote};
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::{AztecAddress},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::token_contract::Token;
use std::test::OracleMock;

pub unconstrained fn setup(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
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

    // Start the test in the account contract address
    env.impersonate(owner);

    // Deploy token contract
    let token_initializer_call_interface = Token::interface().constructor(
        owner,
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
    );
    let token_contract =
        env.deploy("./@token_contract", "Token").with_public_void_initializer(token_initializer_call_interface);
    let token_contract_address = token_contract.to_address();
    env.advance_block_by(1);

    // Deploy nft contract
    let nft_initializer_call_interface = NFT::interface().constructor(
        owner,
        "TestNFT000000000000000000000000",
        "TN00000000000000000000000000000",
        token_contract_address,
    );
    let nft_contract =
        env.deploy_self("NFT").with_public_void_initializer(nft_initializer_call_interface);
    let nft_contract_address = nft_contract.to_address();
    env.advance_block_by(1);
    (&mut env, token_contract_address, nft_contract_address, owner, recipient)
}

pub unconstrained fn setup_and_mint(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, Field, U128) {
    // Setup
    let (env, token_contract_address, nft_contract_address, owner, recipient) = setup(with_account_contracts);

    let minted_amount = U128::from_integer(1);

    Token::at(token_contract_address).mint_to_private(owner, owner, minted_amount).call(&mut env.private());
    env.advance_block_by(1);

    let minted_token_id = 615;

    NFT::at(nft_contract_address).mint(owner, minted_token_id).call(&mut env.public());
    env.advance_block_by(1);

    (env, token_contract_address, nft_contract_address, owner, recipient, minted_token_id, minted_amount)
}

pub unconstrained fn setup_mint_and_transfer_to_private(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, Field, U128) {
    let (env, token_contract_address, nft_contract_address, owner, recipient, minted_token_id, minted_amount) =
        setup_and_mint(with_account_contracts);

    let note_randomness = random();

    // We mock the Oracle to return the note randomness such that later on we can manually add the note
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    // We transfer the public NFT to private.
    NFT::at(nft_contract_address).transfer_to_private(owner, minted_token_id).call(
        &mut env.private(),
    );

    env.advance_block_by(1);

    (env, token_contract_address, nft_contract_address, owner, recipient, minted_token_id, minted_amount)
}

pub unconstrained fn setup_mint_transfer_to_private_and_list(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, Field, U128) {
    let (env, token_contract_address, nft_contract_address, owner, recipient, minted_token_id, minted_amount) =
        setup_mint_and_transfer_to_private(with_account_contracts);

    // Transfer the NFT to recipient so the owner can purchase it
    NFT::at(nft_contract_address).transfer_in_private(owner, recipient, minted_token_id, 0).call(
        &mut env.private(),
    );
    env.advance_block_by(1);

    env.impersonate(recipient);
    // List the NFT as purchasable by owner
    NFT::at(nft_contract_address).list(minted_token_id, minted_amount, owner).call(
        &mut env.private(),
    );

    env.advance_block_by(1);
    env.impersonate(owner);

    (env, token_contract_address, nft_contract_address, owner, recipient, minted_token_id, minted_amount)
}

pub unconstrained fn get_nft_exists(nft_contract_address: AztecAddress, token_id: Field) -> bool {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(nft_contract_address);
    let block_number = get_block_number();

    let nft_exists_slot = NFT::storage_layout().nft_exists.slot;
    let nft_slot = derive_storage_slot_in_map(nft_exists_slot, token_id);
    let exists: bool = storage_read(nft_contract_address, nft_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);

    exists
}

pub unconstrained fn assert_owns_public_nft(
    env: &mut TestEnvironment,
    nft_contract_address: AztecAddress,
    owner: AztecAddress,
    token_id: Field,
) {
    let obtained_owner = NFT::at(nft_contract_address).owner_of(token_id).view(&mut env.public());

    assert(owner == obtained_owner, "Incorrect NFT owner");
}

pub unconstrained fn assert_owns_private_nft(
    nft_contract_address: AztecAddress,
    owner: AztecAddress,
    token_id: Field,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(nft_contract_address);

    // Direct call to unconstrained
    let (private_nfts, _) = NFT::get_private_nfts(owner, 0);

    let mut nft_found = false;
    for obtained_token_id in private_nfts {
        if obtained_token_id == token_id {
            nft_found = true;
        }
    }

    cheatcodes::set_contract_address(current_contract_address);

    assert(nft_found, "NFT not found in private nfts");
}

unconstrained fn owns_private_listing(
    nft_contract_address: AztecAddress,
    listing: ListingNote,
) -> bool {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(nft_contract_address);

    // Direct call to unconstrained
    let (private_listings, _) = NFT::get_private_listings(listing.owner, 0);

    let mut listing_found = false;
    for obtained_listing in private_listings {
        if (obtained_listing.token_id == listing.token_id)
            & (obtained_listing.owner == listing.owner)
            & (obtained_listing.seller == listing.seller)
            & (obtained_listing.buyer == listing.buyer)
            & (obtained_listing.price == listing.price) {
            listing_found = true;
        }
    }

    cheatcodes::set_contract_address(current_contract_address);

    listing_found
}

pub unconstrained fn assert_owns_private_listing(
    nft_contract_address: AztecAddress,
    listing: ListingNote,
) {
    assert(owns_private_listing(nft_contract_address, listing), "Listing not found in private listings");
}

pub unconstrained fn assert_doesnt_own_private_listing(
    nft_contract_address: AztecAddress,
    listing: ListingNote,
) {
    assert(!owns_private_listing(nft_contract_address, listing), "Listing found in private listings");
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}
