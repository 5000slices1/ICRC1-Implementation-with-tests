import T "../../../Types/Types.All";
import Archive "../../../Canisters/Archive";
import { ConstantTypes } = "../../../Types/Types.All";
import Utils "../Utils/Utils";
import Option "mo:base/Option";
import Cycles "mo:base/ExperimentalCycles";
import List "mo:base/List";

module {

    private type TokenData = T.TokenTypes.TokenData;
    let { SB } = Utils;

    // Updates the token's data and manages the transactions
    //
    // **added at the end of any function that creates a new transaction**
    public func append_transactions_into_archive_if_needed(token : TokenData) : async* (Bool, ?Principal) {
        let txs_size = SB.size(token.transactions);

        if (txs_size >= ConstantTypes.MAX_TRANSACTIONS_IN_LEDGER) {

            return await* append_transactions_into_archive_internal(token);
        };

        return (false, null);
    };

    // Moves the transactions from the ICRC1 canister to the archive canister
    // and returns a boolean that indicates the success of the data transfer
    private func append_transactions_into_archive_internal(token : TokenData) : async* (Bool, ?Principal) {
        let { archive; transactions } = token;

        var newArchiveCanisterId : ?Principal = null;
        var canisterWasAdded = false;
        let mainTokenCycleBalance : Nat = Cycles.balance();
        if (archive.stored_txs == 0) {

            if (mainTokenCycleBalance < ConstantTypes.TOKEN_CYCLES_TO_KEEP) {
                return (canisterWasAdded, newArchiveCanisterId);
            };
            Cycles.add<system>(ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL);
            archive.canister := await Archive.Archive();
            newArchiveCanisterId := Option.make(await archive.canister.init(0));
            canisterWasAdded := true;

        } else {
            let add = await* should_add_archive(token);
            if (add == true) {

                if (mainTokenCycleBalance < ConstantTypes.TOKEN_CYCLES_TO_KEEP) {
                    return (canisterWasAdded, newArchiveCanisterId);
                };
                newArchiveCanisterId := Option.make(await* add_additional_archive(token));
                canisterWasAdded := true;
            };
        };

        let cyclesBalance = await archive.canister.cycles_available();
        if (cyclesBalance < ConstantTypes.ARCHIVE_CYCLES_REQUIRED) {
            return (canisterWasAdded, newArchiveCanisterId);
        };

        let res = await archive.canister.append_transactions(
            SB.toArray(transactions)
        );

        switch (res) {
            case (#ok(_)) {
                archive.stored_txs += SB.size(transactions);
                SB.clear(transactions);
            };
            case (#err(_)) {};
        };

        return (canisterWasAdded, newArchiveCanisterId);
    };

    /// Here it is decided if additional archive canister should be created
    public func should_add_archive(token : TokenData) : async* Bool {

        let { archive } = token;
        await archive.canister.memory_is_full();        
    };

    /// Creates a new archive canister
    public func add_additional_archive(token : TokenData) : async* Principal {
        let { archive } = token;

        //Add cycles, because we are creating new canister
        Cycles.add<system>(T.ConstantTypes.ARCHIVE_CYCLES_AUTOREFILL);    
        let newCanister = await Archive.Archive();
                
        let oldCanister = archive.canister;
        let old_last_tx : Nat = await oldCanister.get_last_tx();            
        let canisterId = await newCanister.init(old_last_tx + 1);
        
     
        ignore await oldCanister.set_next_archive(newCanister);
        ignore await newCanister.set_prev_archive(oldCanister);

        archive.canister := newCanister;
        return canisterId;
    };

    public func updateCanisterIdList(principal : Principal, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : async () {

        if (archivePrincipalIdsInList(principal, archive_canisterIds) == false) {
            archive_canisterIds.canisterIds := List.push<Principal>(principal, archive_canisterIds.canisterIds);
        };

    };

    public func archivePrincipalIdsInList(principal : Principal, archive_canisterIds : T.ArchiveTypes.ArchiveCanisterIds) : Bool {

        if (List.size(archive_canisterIds.canisterIds) <= 0) {
            return false;
        };

        func listFindFunc(x : Principal) : Bool {
            x == principal;
        };

        return List.some<Principal>(archive_canisterIds.canisterIds, listFindFunc);
    };

};
