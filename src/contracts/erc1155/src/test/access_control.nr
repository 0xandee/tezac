use crate::ERC1155NFT as NFT;
use crate::test::utils;

#[test]
unconstrained fn access_control() {
    let (env, nft_contract_address, owner, recipient) = utils::setup(false);

    // Set a new admin
    NFT::at(nft_contract_address).set_admin(recipient).call(&mut env.public());

    env.advance_block_by(1);

    // Check it worked
    let admin = NFT::at(nft_contract_address).get_admin().view(&mut env.public());
    assert(admin == recipient.to_field());

    // Impersonate new admin
    env.impersonate(recipient);

    env.advance_block_by(1);
    
    env.impersonate(owner);

    // Try to set ourselves as admin, fail miserably
    env.assert_public_call_fails(NFT::at(nft_contract_address).set_admin(recipient));
}