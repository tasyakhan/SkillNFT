import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";

actor SkillNFT {
    // Struktur NFT Keahlian
    type SkillNFTMetadata = {
        id: Nat;
        owner: Principal;
        name: Text;
        skills: [Text];
        endorsements: Nat;
        createdAt: Int;
    };

    // Penyimpanan NFT
    private var nftCounter : Nat = 0;
    private var skillNFTs = HashMap.HashMap<Nat, SkillNFTMetadata>(10, Nat.equal, Nat.hash);
    private var nftOwnership = HashMap.HashMap<Principal, [Nat]>(10, Principal.equal, Principal.hash);

    // Membuat NFT keahlian baru
    public shared(msg) func createSkillNFT(
        name: Text, 
        skills: [Text]
    ) : async Result.Result<Nat, Text> {
        // Validasi input
        if (Text.size(name) == 0 or skills.size() == 0) {
            return #err("Invalid NFT details");
        };

        let newNFT : SkillNFTMetadata = {
            id = nftCounter;
            owner = msg.caller;
            name = name;
            skills = skills;
            endorsements = 0;
            createdAt = Time.now();
        };

        // Simpan NFT
        skillNFTs.put(nftCounter, newNFT);

        // Update kepemilikan
        switch (nftOwnership.get(msg.caller)) {
            case null { 
                nftOwnership.put(msg.caller, [nftCounter]); 
            };
            case (?existingNFTs) {
                nftOwnership.put(msg.caller, 
                    Array.append(existingNFTs, [nftCounter])
                );
            };
        };

        let currentId = nftCounter;
        nftCounter += 1;
        #ok(currentId)
    };

    // Endorse NFT
    public shared(msg) func endorseSkillNFT(
        nftId: Nat
    ) : async Result.Result<SkillNFTMetadata, Text> {
        switch (skillNFTs.get(nftId)) {
            case null { return #err("NFT not found"); };
            case (?nft) {
                // Hindari self-endorsement
                if (nft.owner == msg.caller) {
                    return #err("Cannot endorse your own NFT");
                };

                let updatedNFT : SkillNFTMetadata = {
                    id = nft.id;
                    owner = nft.owner;
                    name = nft.name;
                    skills = nft.skills;
                    endorsements = nft.endorsements + 1;
                    createdAt = nft.createdAt;
                };

                skillNFTs.put(nftId, updatedNFT);
                #ok(updatedNFT)
            };
        }
    };

    // Transfer NFT
    public shared(msg) func transferSkillNFT(
        nftId: Nat, 
        to: Principal
    ) : async Result.Result<(), Text> {
        switch (skillNFTs.get(nftId)) {
            case null { return #err("NFT not found"); };
            case (?nft) {
                // Pastikan yang mentransfer adalah pemilik
                if (nft.owner != msg.caller) {
                    return #err("Only owner can transfer");
                };

                // Update pemilik NFT
                let updatedNFT : SkillNFTMetadata = {
                    id = nft.id;
                    owner = to;
                    name = nft.name;
                    skills = nft.skills;
                    endorsements = nft.endorsements;
                    createdAt = nft.createdAt;
                };

                skillNFTs.put(nftId, updatedNFT);

                // Update kepemilikan
                switch (nftOwnership.get(msg.caller)) {
                    case null { };
                    case (?existingNFTs) {
                        let updatedSenderNFTs = 
                            Array.filter(existingNFTs, func(id: Nat) : Bool { id != nftId });
                        nftOwnership.put(msg.caller, updatedSenderNFTs);
                    };
                };

                switch (nftOwnership.get(to)) {
                    case null { 
                        nftOwnership.put(to, [nftId]); 
                    };
                    case (?existingNFTs) {
                        nftOwnership.put(to, 
                            Array.append(existingNFTs, [nftId])
                        );
                    };
                };

                #ok()
            };
        }
    };

    // Dapatkan NFT milik pengguna
    public query func getUserSkillNFTs(user: Principal) : async [SkillNFTMetadata] {
        switch (nftOwnership.get(user)) {
            case null { [] };
            case (?nftIds) { 
                Array.mapFilter<?SkillNFTMetadata>(
                    nftIds, 
                    func(id: Nat) : ?SkillNFTMetadata { 
                        skillNFTs.get(id) 
                    }
                )
            };
        }
    };

    // Dapatkan detail NFT
    public query func getSkillNFTDetails(nftId: Nat) : async ?SkillNFTMetadata {
        skillNFTs.get(nftId)
    };
}
