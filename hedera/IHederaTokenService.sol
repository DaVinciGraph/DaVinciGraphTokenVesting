// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

interface IHederaTokenService {
    /// A fixed number of units (hbar or token) to assess as a fee during a transfer of
    /// units of the token to which this fixed fee is attached. The denomination of
    /// the fee depends on the values of tokenId, useHbarsForPayment and
    /// useCurrentTokenForPayment. Exactly one of the values should be set.
    struct FixedFee {

        int64 amount;

        // Specifies ID of token that should be used for fixed fee denomination
        address tokenId;

        // Specifies this fixed fee should be denominated in Hbar
        bool useHbarsForPayment;

        // Specifies this fixed fee should be denominated in the Token currently being created
        bool useCurrentTokenForPayment;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    /// A fraction of the transferred units of a token to assess as a fee. The amount assessed will never
    /// be less than the given minimumAmount, and never greater than the given maximumAmount.  The
    /// denomination is always units of the token to which this fractional fee is attached.
    struct FractionalFee {
        // A rational number's numerator, used to set the amount of a value transfer to collect as a custom fee
        int64 numerator;

        // A rational number's denominator, used to set the amount of a value transfer to collect as a custom fee
        int64 denominator;

        // The minimum amount to assess
        int64 minimumAmount;

        // The maximum amount to assess (zero implies no maximum)
        int64 maximumAmount;
        bool netOfTransfers;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    /// A fee to assess during a transfer that changes ownership of an NFT. Defines the fraction of
    /// the fungible value exchanged for an NFT that the ledger should collect as a royalty. ("Fungible
    /// value" includes both ℏ and units of fungible HTS tokens.) When the NFT sender does not receive
    /// any fungible value, the ledger will assess the fallback fee, if present, to the new NFT owner.
    /// Royalty fees can only be added to tokens of type type NON_FUNGIBLE_UNIQUE.
    struct RoyaltyFee {
        // A fraction's numerator of fungible value exchanged for an NFT to collect as royalty
        int64 numerator;

        // A fraction's denominator of fungible value exchanged for an NFT to collect as royalty
        int64 denominator;

        // If present, the fee to assess to the NFT receiver when no fungible value
        // is exchanged with the sender. Consists of:
        // amount: the amount to charge for the fee
        // tokenId: Specifies ID of token that should be used for fixed fee denomination
        // useHbarsForPayment: Specifies this fee should be denominated in Hbar
        int64 amount;
        address tokenId;
        bool useHbarsForPayment;

        // The ID of the account to receive the custom fee, expressed as a solidity address
        address feeCollector;
    }

    /**********************
     * Direct HTS Calls   *
     **********************/

    /// Single-token variant of associateTokens. Will be mapped to a single entry array call of associateTokens
    /// @param account The account to be associated with the provided token
    /// @param token The token to be associated with the provided account
    function associateToken(address account, address token)
        external
        returns (int64 responseCode);

    /// Transfers tokens where the calling account/contract is implicitly the first entry in the token transfer list,
    /// where the amount is the value needed to zero balance the transfers. Regular signing rules apply for sending
    /// (positive amount) or receiving (negative amount)
    /// @param token The token to transfer to/from
    /// @param sender The sender for the transaction
    /// @param recipient The receiver of the transaction
    /// @param amount Non-negative value to send. a negative value will result in a failure.
    function transferToken(
        address token,
        address sender,
        address recipient,
        int64 amount
    ) external returns (int64 responseCode);

    /// Query token custom fees
    /// @param token The token address to check
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    /// @return fixedFees Set of fixed fees for `token`
    /// @return fractionalFees Set of fractional fees for `token`
    /// @return royaltyFees Set of royalty fees for `token`
    function getTokenCustomFees(address token)
        external
        returns (int64 responseCode, FixedFee[] memory fixedFees, FractionalFee[] memory fractionalFees, RoyaltyFee[] memory royaltyFees);


    /// Query to return the token type for a given address
    /// @param token The token address
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.    
    /// @return tokenType the token type. 0 is FUNGIBLE_COMMON, 1 is NON_FUNGIBLE_UNIQUE, -1 is UNRECOGNIZED   
    function getTokenType(address token)
        external returns 
        (int64 responseCode, int32 tokenType);
}
