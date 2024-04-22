import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import Blobify "mo:memory-buffer/Blobify";
import CommonTypes "../../../Types/Types.Common";
import T "../../../Types/Types.All";
import TypesBackup "../../../Types/Types.BackupRestore";
import TypesAccount "../../../Types/Types.Account";
import TypesToken "../../../Types/Types.Token";
import Utils "../Utils/Utils";
import Converters "../../Converters/Converters";

module {

    let { SB } = Utils;




    

    private func GetTokenMainDataAsNat8Array(token:T.TokenTypes.TokenData):[Nat8]{
        Converters.ConvertToTokenMainDataNat8Array(token);
    };

    private func GetTokenMainDataFromNat8Array(array:[Nat8]):?TypesBackup.BackupCommonTokenData{
        Converters.ConvertToTokenMainDataFromNat8Array(array);
    };





};