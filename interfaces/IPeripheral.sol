// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

interface IPeripheral {
    /**
     * @notice Parameters for opening a new position.
     * @dev Field order and types are load-bearing: they must match
     * `abis/AmmalgamPeripheral.json` (`newPosition`) exactly. Tuple members are
     * positional in ABI encoding, so omitting or reordering a field silently
     * shifts every following slot and produces a transaction that decodes to
     * different values than the caller intended.
     *
     * `from` is the account whose funds are used; `to` is the receiver of the
     * resulting position. They differ whenever a relayer/third party opens a
     * position on someone else's behalf.
     */
    struct PositionParams {
        address pairAddress;
        address from;
        address to;
        uint256 transferX;
        uint256 transferY;
        uint256 mintX;
        uint256 mintY;
        uint256 swapAmountInX;
        uint256 swapAmountInY;
        uint256 swapAmountOutX;
        uint256 swapAmountOutY;
        uint256 borrowLAssets;
    }

    function newPosition(
        PositionParams calldata params
    ) external;

    struct HelperParams {
        address to;
        address pairAddress;
        uint256 amountX;
        uint256 amountY;
    }

    function depositLiquidityHelper(
        HelperParams calldata helperParams
    ) external;

    function depositHelper(
        HelperParams calldata helperParams
    ) external;

    function repayHelper(
        HelperParams calldata helperParams
    ) external;

    function repayFullHelper(
        HelperParams calldata helperParams
    ) external;

    function repayLiquidityHelper(
        HelperParams calldata helperParams
    ) external;

    function repayLiquidityFullHelper(
        HelperParams calldata helperParams
    ) external;

    function withdrawHelper(
        HelperParams calldata helperParams
    ) external;

    function withdrawLiquidityHelper(address to, address pairAddress, uint256 amount) external;

    /**
     * @notice Parameters for closing a position.
     * @dev Field order and types must match `abis/AmmalgamPeripheral.json`
     * (`close`) exactly — see the note on `PositionParams` above.
     */
    struct ClosePositionInputParams {
        address pairAddress;
        address from;
        uint256 burnL;
        uint256 withdrawX;
        uint256 withdrawY;
    }

    function close(
        ClosePositionInputParams calldata params
    ) external;

    /// @notice Check whether `delegatee` is permitted to act for `onBehalfOf`.
    function delegationAllowance(
        address onBehalfOf,
        address delegatee
    ) external view returns (bool);

    /// @notice Grant or revoke `delegatee`'s right to act on the caller's behalf.
    function updateDelegation(address delegatee, bool allowed) external;
}
