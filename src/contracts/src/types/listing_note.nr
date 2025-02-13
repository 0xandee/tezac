use dep::aztec::{
    macros::notes::partial_note,
    prelude::{NoteHeader, NullifiableNote, PrivateContext},
    protocol_types::{address::AztecAddress, traits::Packable},
    note::utils::compute_note_hash_for_nullify,
    protocol_types::{
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
    },
    oracle::random::random,
    keys::getters::{get_nsk_app, get_public_keys},
};

#[partial_note(quote {token_id, price})]
pub struct ListingNote {
    token_id: Field,
    price: Field,
    seller: AztecAddress,
    isSold: bool,
    randomness: Field,
}

impl ListingNote {
    pub fn new(token_id: Field, price: Field, seller: AztecAddress, isSold: bool) -> Self {
        let randomness = unsafe { random() };
        ListingNote {
            token_id,
            price,
            seller,
            randomness,
            isSold,
            header: NoteHeader::empty()
        }
    }

    // pub fn is_expired(self, current_time: Field) -> bool {
    // let expiry_int = self.expiry as u64;
    // let current_time_int = current_time as u64;
    // current_time_int > expiry_int
    // }
}

impl NullifiableNote for ListingNote {
    fn compute_nullifier(
        self,
        context: &mut PrivateContext,
        note_hash_for_nullify: Field,
    ) -> Field {
        let seller_npk_m_hash: Field = get_public_keys(self.seller).npk_m.hash();
        let secret = context.request_nsk_app(seller_npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }

        unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let seller_npk_m_hash: Field = get_public_keys(self.seller).npk_m.hash();
        let secret = get_nsk_app(seller_npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }
}

impl Eq for ListingNote {
    fn eq(self, other: Self) -> bool {
        (self.token_id == other.token_id)
            & (self.seller == other.seller)
            & (self.randomness == other.randomness)
    }
}
