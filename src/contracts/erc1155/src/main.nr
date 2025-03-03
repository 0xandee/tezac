mod types;
mod test;

use dep::aztec::macros::aztec;

#[aztec]
contract ERC1155NFT {
    use crate::types::uint_note::UintNote; 
    use dep::authwit::auth::{
        assert_current_call_valid_authwit, assert_current_call_valid_authwit_public,
        compute_authwit_nullifier,
    };
    use dep::aztec::{
        encrypted_logs::log_assembly_strategies::default_aes128::note::encode_and_encrypt_note,
        macros::{
            events::event,
            functions::{initializer, internal, private, public, view},
            storage::storage,
        },
        note::constants::MAX_NOTES_PER_PAGE,
        oracle::random::random,
        prelude::{
            AztecAddress, Map, NoteGetterOptions, NoteViewerOptions, PrivateContext, PrivateSet,
            PublicContext, PublicImmutable, PublicMutable,
        },
        protocol_types::{point::Point, traits::Serialize, traits::Packable},
        utils::comparison::Comparator,
    };
    use dep::compressed_string::FieldCompressedString;
    use std::meta::derive;

    #[derive(Serialize)]
    #[event]
    pub struct NFTTransfer {
        from: AztecAddress,
        to: AztecAddress,
        token_id: Field,
        amount: U128,
    }

    #[derive(Packable)]
    pub struct TokenBalance {
        owner: AztecAddress,
        amount: U128,
    }

    #[storage]
    struct Storage<Context> {
        symbol: PublicImmutable<FieldCompressedString, Context>,
        name: PublicImmutable<FieldCompressedString, Context>,
        admin: PublicMutable<AztecAddress, Context>,
        private_balances: Map<Field, Map<AztecAddress, PrivateSet<UintNote, Context>, Context>, Context>,
        nft_total_supply: Map<Field, PublicMutable<U128, Context>, Context>,
        public_balances: Map<Field, Map<AztecAddress, PublicMutable<U128, Context>, Context>, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(admin: AztecAddress, name: str<31>, symbol: str<31>) {
        assert(!admin.is_zero(), "invalid admin");
        storage.admin.write(admin);
        storage.name.initialize(FieldCompressedString::from_string(name));
        storage.symbol.initialize(FieldCompressedString::from_string(symbol));
    }

    #[public]
    fn set_admin(new_admin: AztecAddress) {
        assert(storage.admin.read().eq(context.msg_sender()), "caller is not an admin");
        storage.admin.write(new_admin);
    }

    #[public]
    fn mint(to: AztecAddress, token_id: Field, amount: U128) {
        assert(token_id != 0, "zero token ID not supported");
        assert(amount.to_integer() > 0, "amount must be greater than 0");

        let total_supply_storage = storage.nft_total_supply.at(token_id);
        total_supply_storage.write(total_supply_storage.read() + amount);
        
        let balance_storage = storage.public_balances.at(token_id).at(to);
        balance_storage.write(balance_storage.read() + amount);
    }

    #[public]
    #[view]
    fn public_get_name() -> pub FieldCompressedString {
        storage.name.read()
    }

    #[private]
    #[view]
    fn private_get_name() -> pub FieldCompressedString {
        storage.name.read()
    }

    #[public]
    #[view]
    fn public_get_symbol() -> pub FieldCompressedString {
        storage.symbol.read()
    }

    #[private]
    #[view]
    fn private_get_symbol() -> pub FieldCompressedString {
        storage.symbol.read()
    }

    #[public]
    #[view]
    fn get_admin() -> Field {
        storage.admin.read().to_field()
    }

    #[public]
    fn transfer_in_public(from: AztecAddress, to: AztecAddress, token_id: Field, amount: U128, nonce: Field) {
        assert(amount.to_integer() > 0, "amount must be greater than 0");
            
        let balance_from = storage.public_balances.at(token_id).at(from);
        assert(balance_from.read() >= amount, "insufficient balance");

        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit_public(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }

        if (!from.eq(to)) {
            balance_from.write(balance_from.read() - amount);

            let balance_to = storage.public_balances.at(token_id).at(to);
            balance_to.write(balance_to.read() + amount);
        }
    }

    #[private]
    fn transfer_to_private(to: AztecAddress, token_id: Field, amount: U128) {
        let from = context.msg_sender();

        let nft = ERC1155NFT::at(context.this_address());

        // We prepare the private balance increase.
        let hiding_point_slot = _prepare_private_balance_increase(token_id, to, &mut context, storage);

        let notes = storage.private_balances.at(token_id).at(to).pop_notes(NoteGetterOptions::new()
            .select(UintNote::properties().owner, Comparator.EQ, to)
            .set_limit(1));
            
        let new_private_balance = notes.get_unchecked(0).value + amount;

        // At last we finalize the transfer. Usage of the `unsafe` method here is safe because we set the `from`
        // function argument to a message sender, guaranteeing that he can transfer only his own NFTs.
        nft._finalize_transfer_to_private_unsafe(from, token_id, amount, new_private_balance, hiding_point_slot).enqueue(
            &mut context,
        );
    }

    /// Prepares an increase of private balance of `to` (partial note). The increase needs to be finalized by calling
    /// `finalize_transfer_to_private. Returns a hiding point slot.
    // docs:start:prepare_private_balance_increase
    #[private]
    fn prepare_private_balance_increase(token_id: Field, to: AztecAddress) -> Field {
        _prepare_private_balance_increase(token_id, to, &mut context, storage)
    }
    
    /// This function exists separately from `prepare_private_balance_increase` solely as an optimization as it allows
    /// us to have it inlined in the `transfer_to_private` function which results in one less kernel iteration.
    ///
    #[contract_library_method]
    fn _prepare_private_balance_increase(
        token_id: Field,
        to: AztecAddress,
        context: &mut PrivateContext,
        storage: Storage<&mut PrivateContext>,
    ) -> Field {
        let to_note_slot = storage.private_balances.at(token_id).at(to).storage_slot;

        // We create a setup payload with unpopulated/zero token id for 'to'

        /// Safety: We use the randomness to preserve the privacy of the note recipient by preventing brute-forcing,
        /// so a malicious sender could use non-random values to make the note less private. But they already know
        /// the full note pre-image anyway, and so the recipient already trusts them to not disclose this
        /// information. We can therefore assume that the sender will cooperate in the random value generation.
        let note_randomness = unsafe { random() };
        let note_setup_payload = UintNote::setup_payload().new(to, note_randomness, to_note_slot);

        let setup_log = note_setup_payload.encrypt_log(context, to, context.msg_sender());

        // Using the x-coordinate as a hiding point slot is safe against someone else interfering with it because
        // we have a guarantee that the public functions of the transaction are executed right after the private ones
        // and for this reason the protocol guarantees that nobody can front-run us in consuming the hiding point.
        // This guarantee would break if `finalize_transfer_to_private` was not called in the same transaction. This
        // however is not the flow we are currently concerned with. To support the multi-transaction flow we could
        // introduce a `from` function argument, hash the x-coordinate with it and then repeat the hashing in
        // `finalize_transfer_to_private`.

        // We can also be sure that the `hiding_point_slot` will not overwrite any other value in the storage because
        // in our state variables we derive slots using a different hash function from multi scalar multiplication
        // (MSM).
        let hiding_point_slot = note_setup_payload.hiding_point.x;

        // We don't need to perform a check that the value overwritten by `_store_point_in_transient_storage_unsafe`
        // is zero because the slot is the x-coordinate of the hiding point and hence we could only overwrite
        // the value in the slot with the same value. This makes usage of the `unsafe` method safe.
        ERC1155NFT::at(context.this_address())
            ._store_payload_in_transient_storage_unsafe(
                hiding_point_slot,
                note_setup_payload.hiding_point,
                setup_log,
            )
            .enqueue(context);

        hiding_point_slot
    }

    // TODO(#9375): Having to define the note log length here is very unfortunate as it's basically impossible for
    // users to derive manually. This will however go away once we have a real transient storage since we will not need
    // the public call and instead we would do something like `context.transient_storage_write(slot, payload)` and that
    // will allow us to use generics and hence user will not need to define it explicitly. We cannot use generics here
    // as it is an entrypoint function.
    // docs:start:store_payload_in_transient_storage_unsafe
    #[public]
    #[internal]
    fn _store_payload_in_transient_storage_unsafe(
        slot: Field,
        point: Point,
        setup_log: [Field; 9],
    ) {
        context.storage_write(slot, point);
        context.storage_write(slot + aztec::protocol_types::point::POINT_LENGTH as Field, setup_log);
    }

    /// Finalizes a transfer of NFT with `token_id` from public balance of `from` to a private balance of `to`.
    /// The transfer must be prepared by calling `prepare_private_balance_increase` first and the resulting
    /// `hiding_point_slot` must be passed as an argument to this function.
    // docs:start:finalize_transfer_to_private
    #[public]
    fn finalize_transfer_to_private(token_id: Field, amount: U128, new_private_amount: U128, hiding_point_slot: Field) {
        let from = context.msg_sender();
        _finalize_transfer_to_private(from, token_id, amount, new_private_amount, hiding_point_slot, &mut context, storage);
    }

    #[public]
    #[internal]
    fn _finalize_transfer_to_private_unsafe(
        from: AztecAddress,
        token_id: Field,
        amount: U128,
        new_private_amount: U128,
        hiding_point_slot: Field,
    ) {
        _finalize_transfer_to_private(from, token_id, amount, new_private_amount, hiding_point_slot, &mut context, storage);
    }

    #[contract_library_method]
    fn _finalize_transfer_to_private(
        from: AztecAddress,
        token_id: Field,
        amount: U128,
        new_private_amount: U128,
        hiding_point_slot: Field,
        context: &mut PublicContext,
        storage: Storage<&mut PublicContext>,
    ) {
        assert(amount > U128::from_integer(0), "amount must be greater than 0");

        let balance_storage = storage.public_balances.at(token_id).at(from);
        assert(balance_storage.read() >= amount, "insufficient balance");
        
        balance_storage.write(balance_storage.read() - amount);

        let finalization_payload =
            UintNote::finalization_payload().new(context, hiding_point_slot, new_private_amount);

        // At last we emit the note hash and the final log
        finalization_payload.emit();
    }

    //
    // Cancel a private authentication witness.
    // @param inner_hash The inner hash of the authwit to cancel.
    //
    #[private]
    fn cancel_authwit(inner_hash: Field) {
        let on_behalf_of = context.msg_sender();
        let nullifier = compute_authwit_nullifier(on_behalf_of, inner_hash);
        context.push_nullifier(nullifier);
    }

    #[private]
    fn transfer_in_private(from: AztecAddress, to: AztecAddress, token_id: Field, amount: U128, nonce: Field) {
        assert(amount > U128::from_integer(0), "amount must be greater than 0");
        
        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }

        if (!from.eq(to)) {
            let balances = storage.private_balances;
            let notes = balances.at(token_id).at(from).pop_notes(NoteGetterOptions::new()
                .select(UintNote::properties().owner, Comparator.EQ, from)
                .set_limit(1));

            let from_balance = notes.get_unchecked(0).value;
            assert(from_balance >= amount, "insufficient balance");

            let to_balance = balances.at(token_id).at(to).pop_notes(NoteGetterOptions::new()
                .select(UintNote::properties().owner, Comparator.EQ, to)
                .set_limit(1)).get_unchecked(0).value;

            let mut new_from_note = UintNote::new(from_balance - amount, from);
            let mut new_to_note = UintNote::new(to_balance + amount, to);

            balances.at(token_id).at(from).insert(&mut new_from_note);
            balances.at(token_id).at(to).insert(&mut new_to_note).emit(encode_and_encrypt_note(&mut context, to, from));
        }
    }

    #[private]
    fn transfer_to_public(from: AztecAddress, to: AztecAddress, token_id: Field, amount: U128, nonce: Field) {
        assert(amount > U128::from_integer(0), "amount must be greater than 0");

        if (!from.eq(context.msg_sender())) {
            assert_current_call_valid_authwit(&mut context, from);
        } else {
            assert(nonce == 0, "invalid nonce");
        }

        let balances = storage.private_balances;
        let notes = balances.at(token_id).at(from).pop_notes(NoteGetterOptions::new()
            .select(UintNote::properties().owner, Comparator.EQ, from)
            .set_limit(1));

        let balance = notes.get_unchecked(0).value;
        assert(balance >= amount, "insufficient balance");

        let mut new_note = UintNote::new(balance - amount, from);
        balances.at(token_id).at(from).insert(&mut new_note);

        ERC1155NFT::at(context.this_address())._finish_transfer_to_public(to, token_id, amount).enqueue(
            &mut context,
        );
    }

    #[public]
    #[internal]
    fn _finish_transfer_to_public(to: AztecAddress, token_id: Field, amount: U128) {
        let balance_storage = storage.public_balances.at(token_id).at(to);
        balance_storage.write(balance_storage.read() + amount);
    }

    #[public]
    #[view]
    fn balance_of(owner: AztecAddress, token_id: Field) -> U128 {
        storage.public_balances.at(token_id).at(owner).read()
    }

   unconstrained fn get_private_balance_of(
        owner: AztecAddress,
        token_id: Field
   ) -> U128 {
        let mut options = NoteViewerOptions::new();
        let notes = storage.private_balances.at(token_id).at(owner).view_notes(options.set_offset(0));
        notes.get_unchecked(0).value
    }
}
