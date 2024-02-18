import DatabaseTypes "../Types/Types.Database";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import StableTrieMap "mo:StableTrieMap";
import Region "mo:base/Region";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

//The database is stored in stable memory

module{

 public type Index = Nat64;
 let indexBlob_size = 16 : Nat64; /* two Nat64s, for pos and size. */

  public func getNewIndexBasedDatabaseItem() : DatabaseTypes.IndexBasedDatabaseItem {
    let result : DatabaseTypes.IndexBasedDatabaseItem = {
      
      bytes = Region.new(); //will be stored as blob
      var bytes_count : Nat64 = 0;

      elems = Region.new(); //will be stored as Nat64
      var elems_count : Nat64 = 0;
    };
    return result;
  };


  private func getSize(item : DatabaseTypes.IndexBasedDatabaseItem) : Nat64 {
    item.elems_count;
  };

  private func getBlobByIndex(item : DatabaseTypes.IndexBasedDatabaseItem, index : Index) : Blob {
    assert index < item.elems_count;
    let pos = Region.loadNat64(item.elems, index * indexBlob_size);
    let size = Region.loadNat64(item.elems, index * indexBlob_size + 8);
    let elem = { pos; size };
    Region.loadBlob(item.bytes, elem.pos, Nat64.toNat(elem.size));
  };

  private func insertNewIndexBasedBlob(encodedPrincipal : Blob, item : DatabaseTypes.IndexBasedDatabaseItem, blobToStore : Blob) : Nat64 {
    let index = item.elems_count;
    item.elems_count += 1;

    let elem_pos = item.bytes_count;
    item.bytes_count += Nat64.fromNat(blobToStore.size());
    regionEnsureSizeBytes(item.bytes, item.bytes_count);
    Region.storeBlob(item.bytes, elem_pos, blobToStore);

    regionEnsureSizeBytes(item.elems, item.elems_count * indexBlob_size);
    Region.storeNat64(item.elems, index * indexBlob_size + 0, elem_pos);
    Region.storeNat64(item.elems, index * indexBlob_size + 8, Nat64.fromNat(blobToStore.size()));
    return index;
  };

  // Grow a region to hold a certain number of total bytes.
  private func regionEnsureSizeBytes(region : Region, new_byte_count : Nat64) {
    let pages = Region.size(region);
    if (new_byte_count > pages << 16) {
      let new_pages = pages + ((new_byte_count + ((1 << 16) - 1)) / (1 << 16));
      assert Region.grow(region, new_pages) == pages;
    };
  };







};