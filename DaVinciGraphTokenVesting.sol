// SPDX-License-Identifier: MIT
// Specifies the license under which the code is distributed (MIT License).

// Website: davincigraph.io
// The website associated with this contract.

// Specifies the version of Solidity compiler to use.
pragma solidity ^0.8.9;

// Imports the SafeHTS library, which provides methods for safely interacting with Hedera Token Service (HTS).
import "./hedera/SafeHTS.sol";

// Imports the ReentrancyGuard and ownable contracts from the OpenZeppelin Contracts package, which helps protect against reentrancy attacks.
import "./openzeppelin/ReentrancyGuard.sol";
import "./openzeppelin/Ownable.sol";

contract DaVinciGraphTokenVesting is Ownable, ReentrancyGuard {
    uint256 public feeOfAddingInTinycents = 1000e8; // $10
    uint256 public feeOfWithdrawalInTinycents = 200e8; // $2

    uint256 public MAX_FEE_IN_TINYCENTS = 5000e8; // $50

    uint64 private constant MIN_PERIOD = 1 hours; //
    uint64 private constant MAX_PERIOD = 10 * 365 days; // Approximately 10 years

    // Struct to store information about Vestings
    struct VestingInfo {
        uint64 start;
        uint64 vestingDuration;
        uint64 periodDuration;
        int64 totalAmount;
        int64 releasedAmount;
    }
    
    // a state to hold vesting schedules
    // tokenAddress => creatorAddress => beneficiaryAddress => schedule
    mapping(address => mapping(address => mapping(address => VestingInfo))) public vestingSchedules;

    constructor() {}

    // associate a Fungible token to the contract
    function associateToken(address token) external onlyOwner {
        // reject invalid token addresses
        require(token != address(0), "Token address must be provided");

        // reject tokens other than non-fungibles
        require( SafeHTS.safeGetTokenType(token) == 0, "Only fungible tokens are allowed" );

        // associate the token using safeHTS library
        SafeHTS.safeAssociateToken(token, address(this));

        emit TokenAssociated(token);
    }

    // transfer the token's total vesting amount ot the contract and create a schedule for the token
    function addSchedule(address token, address beneficiary, int64 amount, uint64 start, uint64 vestingDuration, uint64 periodDuration) external payable nonReentrant {
        // handle the fee
        uint256 fee = SafeHTS.tinycentsToTinybars(feeOfAddingInTinycents);
        require(msg.value >= fee, "Insufficient payment");

        // validate the values
        uint64 currentTimestamp = uint256ToUint64(block.timestamp);
        validateNewScheduleValues(token, beneficiary, uint64(amount), start, vestingDuration, periodDuration, currentTimestamp);

        // reject if schedule already exists
        require(vestingSchedules[token][msg.sender][beneficiary].totalAmount == 0, "Vesting schedule already exists");

        // transfer the vesting amount to the contract
        SafeHTS.safeTransferToken(token, msg.sender, address(this), amount);

        // add the new schedule to the contract state
        vestingSchedules[token][msg.sender][beneficiary] = VestingInfo(start, vestingDuration, periodDuration, amount, 0);
        
        // refund any extra fee that creator might have sent by mistake
        refundExcessFee(fee);

        // emit the new schedule event
        emit ScheduleAdded(msg.sender, token, beneficiary, amount, start, vestingDuration, periodDuration);
    }

    // calculate the released amount and transfer it to the beneficiary if any
    function withdrawReleasedAmount(address token, address creator, address beneficiary) external payable nonReentrant {
        // handle the fee
        uint256 fee = SafeHTS.tinycentsToTinybars(feeOfWithdrawalInTinycents);
        require(msg.value >= fee, "Insufficient payment");

        // reject invalid token addresses
        require(token != address(0), "Token address must be provided");

        // reject invalid creator addresses
        require(creator != address(0), "Creator address must be provided");

        // reject invalid beneficiary addresses
        require(beneficiary != address(0), "Creator address must be provided");

        // reject if schedule doesn't exist
        require(vestingSchedules[token][creator][beneficiary].totalAmount > 0, "There is no vesting schedule with this data");

        // get the vesting
        VestingInfo storage vesting = vestingSchedules[token][creator][beneficiary];

        // get the current timestamp
        uint64 currentTimestamp = uint256ToUint64(block.timestamp);
        
        // calculate and get the unreleased amount
        int64 unreleasedAmount = calculateUnreleasedAmount(vesting, currentTimestamp);

        // Prevents the withdrawal of tokens with custom fees. This scenario might never occur, but the check serves as a precautionary measure.
        preventWithdrawOfTokenWithCustomFees(token);
        
        // add the recent released amount to the vesting state
        vesting.releasedAmount += unreleasedAmount;

        // transfer the unreleased tokens to the vested account
        SafeHTS.safeTransferToken(token, address(this), beneficiary, unreleasedAmount);
        
        // Refund the excess fee
        refundExcessFee(fee);

        // handling events
        if (vesting.releasedAmount >= vesting.totalAmount) {
            // this release was the last one of the vesting
            // delete the vesting schedule from the contract state
            delete vestingSchedules[token][creator][beneficiary];

            // emit ending of the vesting event
            emit VestingEnded(creator, token, beneficiary, unreleasedAmount);
        }else {
            // emit a release event
            emit AmountReleased(creator, token, beneficiary, unreleasedAmount);
        }
    }

    // get a specific VestingInfo, returns an empty VestingInfo when the schedule doesn't exist
    function getVestingInfo(address token, address creator, address beneficiary) public view returns (VestingInfo memory) {
        return vestingSchedules[token][creator][beneficiary];
    }

    // update the vesting/release fee
    function updateFee(uint256 _feeOfAddingInTinycents) external onlyOwner {
        require( _feeOfAddingInTinycents <= MAX_FEE_IN_TINYCENTS, "Fee cannot excess the maximum");

        feeOfAddingInTinycents = _feeOfAddingInTinycents;

        // fee of release is alway 20% of the add schedule fee
        feeOfWithdrawalInTinycents = _feeOfAddingInTinycents / 5;

        emit FeeUpdated(_feeOfAddingInTinycents);
    }

    // withdraw the collected fees from the contract
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;

        // reject if the balance is less than 100 hbar, they'll be reserved for auto renewal
        require(balance > 100e8, "No balance to withdraw.");

        // calculate the withdrawal amount
        uint256 withdrawalAmount = balance - 100e8;

        // retrieve the contract owner address
        address contractOwner = owner();

        // transfer the amount to the owner's address
        (bool success, ) = contractOwner.call{value: withdrawalAmount}("");

        // reject if withdrawal failed
        require(success, "Withdrawal failed.");

        emit FeeWithdrawn(contractOwner, withdrawalAmount);
    }
    
    // set of conditions to check if data provided to create a new schedule is valid
    function validateNewScheduleValues(address token, address beneficiary, uint64 amount, uint64 start, uint64 vestingDuration, uint64 periodDuration, uint64 currentTimestamp) internal pure {
        // reject if token is not set
        require(token != address(0), "Token address must be provided");

        // reject if beneficiary is not set
        require(beneficiary != address(0), "Beneficiary address must be provided");
        
        // reject if amount is not provided
        require(amount > 0, "You must provide amount");

        // reject if the vesting duration is not divisible by the period duration
        require(vestingDuration % periodDuration == 0, "Vesting duration must be evenly divisible by period duration");
        
        // reject if starting point is not greater than current time, minus one minute for insuring the possiblity of a delay
        require(start > currentTimestamp - 1 minutes, "Start time must be greater than now");

        // reject if starting point is too far in the future
        require(start <= currentTimestamp + 10 * 365 days, "Start time cannot be longer than 10 years from now");
        
        // reject if vesting duration is too short
        require(vestingDuration >= 1 hours, "Min vesting duration is 1 hour.");

        // reject if the period duration is not in the min/max range
        require(periodDuration >= MIN_PERIOD && periodDuration <= MAX_PERIOD, "Period must be between 1 hour to 10 years");

        // reject if number of periods are higher than 120
        uint64 totalPeriods = vestingDuration / periodDuration;
        require(totalPeriods <= 120, "Number of vesting iterations exceeds the limi of 120");

        // reject if the distribution of the amount among the periods couldn't be calculated.
        require(amount >= totalPeriods, "Each period must receive at least 1 unit of the token");
    }

    // calculate the vested amount
    function calculateTotalVestedAmount(VestingInfo storage vesting, uint64 currentTimestamp) internal view returns (int64) {
        if (currentTimestamp < vesting.start) {
            // return zero if vesting hasn't started
            return 0;
        } else if (currentTimestamp >= vesting.start + vesting.vestingDuration) {
            // release all remaining tokens, when it's the final period
            return vesting.totalAmount; 
        } else {
            // how many periods are completed
            uint64 elapsedPeriods = (currentTimestamp - vesting.start) / vesting.periodDuration;

            // total periods
            uint64 totalPeriods = vesting.vestingDuration / vesting.periodDuration;

            // share of each period
            uint64 vestedPerPeriod = uint64(vesting.totalAmount) / totalPeriods;

            // total amount that has been vested
            return int64(elapsedPeriods * vestedPerPeriod);
        }
    }

    // calculates the amount that is released but has not withdrawn
    function calculateUnreleasedAmount(VestingInfo storage vesting, uint64 currentTimestamp) internal view returns (int64 unreleased){
        int64 totalVestedAmount = calculateTotalVestedAmount(vesting, currentTimestamp);
        unreleased = totalVestedAmount - vesting.releasedAmount;

        // if the calculated unreleased amount was zero, reject the release request
        require(unreleased > 0, "No tokens to release");

        return unreleased;
    }

    // tokens will be associated only through contract owner, and the owner has the obligation to prevent asossciation of tokens with custom fees
    // tokens with custom fees has the potential to drain the contranct token balance
    // this is just a reassurance check to make trust between contract owners and users that no token with custom fees ever get the chance, even if they are associated to the contract by mistake
    function preventWithdrawOfTokenWithCustomFees(address token) internal {
        // retrieve token custom fee schedules 
        (IHederaTokenService.FixedFee[] memory fixedFees, IHederaTokenService.FractionalFee[] memory fractionalFees, IHederaTokenService.RoyaltyFee[] memory royaltyFees) = SafeHTS.safeGetTokenCustomFees(token);

        // reject if there is any kind of custom fees on the token
        require(fixedFees.length == 0 && fractionalFees.length == 0 && royaltyFees.length == 0, "Tokens with custom fees cannot be withdrawn");
    }

    // calculate the extra fee that user might have sent and send it back
    function refundExcessFee(uint256 feeInTinybars) internal {
        uint256 excessFee = msg.value - feeInTinybars;
        if (excessFee > 0.1e8) {
            (bool success, ) = msg.sender.call{value: excessFee}("");
            require(success, "Refund failed");
        }
    }

    // convert uint256 value to uint64
    function uint256ToUint64(uint256 unsignedValue) internal pure returns (uint64) {
        // Define the maximum value that can fit in an uint64
        uint256 maxInt64Value = 2**64 - 1;

        // Check that the unsigned value is within the range of uint64
        require(unsignedValue <= maxInt64Value, "Value out of uint64 range");

        // Perform the conversion
        return uint64(unsignedValue);
    }
   
    // Events
    event TokenAssociated(address indexed token);
    event ScheduleAdded(address indexed creator, address indexed token, address indexed beneficiary, int64 amount, uint64 start, uint64 vestingDuration, uint64 periodDuration);
    event AmountReleased(address indexed creator, address indexed token, address indexed beneficiary, int64 amount);
    event VestingEnded(address indexed creator, address indexed token, address indexed beneficiary, int64 amount);
    event FeeUpdated(uint256 newFee);
    event FeeWithdrawn(address indexed receiver, uint256 amount);
}