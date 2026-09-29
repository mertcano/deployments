// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {ITransferValidator} from 'interfaces/callbacks/ITransferValidator.sol';
import {ITokenController} from 'interfaces/tokens/ITokenController.sol';

interface IAmmalgamPair is ITokenController, ITransferValidator {
    /**
     * @dev Emitted on a token swap
     * @param sender The address initiating the swap
     * @param amountXIn The amount of token X provided for the swap
     * @param amountYIn The amount of token Y provided for the swap
     * @param amountXOut The amount of token X received from the swap
     * @param amountYOut The amount of token Y received from the swap
     * @param to Address where the swapped tokens are sent
     */
    event Swap(
        address indexed sender,
        uint256 amountXIn,
        uint256 amountYIn,
        uint256 amountXOut,
        uint256 amountYOut,
        address indexed to
    );

    /**
     * @dev Emitted when a borrower position is liquidated.
     * @dev `seized*` assets leave the borrower's position, `repay*Assets` are the
     * nominal repayment, and `actualRepaid*Assets` is what was actually pulled
     * after applying the liquidation penalty. The distinction matters for
     * accounting: `repay*` alone overstates the loss to the pool.
     * @param borrower The liquidated borrower
     * @param to The receiver of the seized assets
     * @param seizedLAssets Liquidity shares seized from the borrower
     * @param seizedXAssets Asset X seized from the borrower
     * @param seizedYAssets Asset Y seized from the borrower
     * @param repayXAssets Nominal asset X repayment
     * @param repayYAssets Nominal asset Y repayment
     * @param actualRepaidXAssets Asset X actually pulled from the liquidator
     * @param actualRepaidYAssets Asset Y actually pulled from the liquidator
     * @param liquidationType The liquidation path taken
     */
    event Liquidate(
        address indexed borrower,
        address indexed to,
        uint256 seizedLAssets,
        uint256 seizedXAssets,
        uint256 seizedYAssets,
        uint256 repayXAssets,
        uint256 repayYAssets,
        uint256 actualRepaidXAssets,
        uint256 actualRepaidYAssets,
        uint256 liquidationType
    );

    /**
     * @dev Emitted when bad debt is written off against a borrower's position.
     * @param borrower The borrower whose bad debt was burned
     * @param tokenType The amalgam token type the bad debt was booked against
     * @param badDebtAssets The amount of bad debt written off
     * @param badDebtShares The shares burned to cover the bad debt
     */
    event BurnBadDebt(address indexed borrower, uint256 indexed tokenType, uint256 badDebtAssets, uint256 badDebtShares);

    /**
     * @notice Mints tokens and assigns them to `to` address.
     * @dev Calculates the amount of tokens to mint based on reserves and balances. Requires liquidity > 0.
     * Emits a #Mint event.
     * @param to address to which tokens will be minted
     * @return liquidity amount of tokens minted
     */
    function mint(
        address to
    ) external returns (uint256 liquidity);

    /**
     * @notice Burns liquidity tokens from the contract and sends the underlying assets to `to` address.
     * @dev Calculates the amounts of assets to be returned based on liquidity.
     *      Requires amountXAssets and amountYAssets to be greater than 0.
     *      Emits a #Burn event and performs a safe transfer of assets.
     * @param to address to which the underlying assets will be transferred
     * @return amountXAssets amount of first token to be returned
     * @return amountYAssets amount of second token to be returned
     */
    function burn(
        address to
    ) external returns (uint256 amountXAssets, uint256 amountYAssets);

    /**
     * @notice Executes a swap of tokens.
     * @dev Requires at least one of `amountXOut` and `amountYOut` to be greater than 0,
     *      and that the amount out does not exceed the reserves.
     *      An optimistically transfer of tokens is performed.
     *      A callback is executed if `data` is not empty.
     *      Emits a #Swap event.
     * @param amountXOut Amount of first token to be swapped out.
     * @param amountYOut Amount of second token to be swapped out.
     * @param to Address to which the swapped tokens are sent.
     * @param data Data to be sent along with the call, can be used for a callback.
     */
    function swap(uint256 amountXOut, uint256 amountYOut, address to, bytes calldata data) external;

    /**
     * @notice Handles deposits into the contract.
     * @dev Verifies deposit amounts and types, adjusts reserves if necessary, mints corresponding tokens, and updates missing assets.
     * @param to Address to which tokens will be minted.
     */
    function deposit(
        address to
    ) external;

    /**
     * @notice Handles withdrawals from the contract.
     * @dev Verifies withdrawal amounts, burns corresponding tokens, transfers the assets, and updates missing assets.
     * @param to Address to which the withdrawn assets will be transferred.
     */
    function withdraw(
        address to
    ) external;

    /**
     * @notice Handles borrowing from the contract.
     * @dev Verifies the borrowing amounts, mints corresponding debt tokens, transfers the assets, and updates missing assets. Also supports flash loan interactions.
     * @param to Address to which the borrowed assets will be transferred.
     * @param amountXAssets Amount of asset X to borrow.
     * @param amountYAssets Amount of asset Y to borrow.
     * @param data Call data to be sent to external contract if flash loan interaction is desired.
     */
    function borrow(address to, uint256 amountXAssets, uint256 amountYAssets, bytes calldata data) external;

    /**
     * @notice Handles liquidity borrowing from the contract.
     * @dev Verifies the borrowing amount, mints corresponding tokens, transfers the assets, and updates reserves. Also supports flash loan interactions.
     * @param borrowAmountLShares Amount of liquidity to borrow.
     * @param data Call data to be sent to external contract if flash loan is desired.
     * @return borrowedLX Amount of asset X borrowed.
     * @return borrowedLY Amount of asset Y borrowed.
     */
    function borrowLiquidity(
        address to,
        uint256 borrowAmountLShares,
        bytes calldata data
    ) external returns (uint256, uint256);

    /**
     * @notice Handles repayment of borrowed assets.
     * @dev Burns corresponding borrowed tokens, adjusts the reserves, and updates missing assets.
     * @param onBehalfOf Address of the entity on whose behalf the repayment is made.
     */
    function repay(
        address onBehalfOf
    ) external;

    /**
     * @notice Handles repayment of borrowed liquidity.
     * @dev Calculates repayable liquidity, burns corresponding tokens, adjusts reserves, and updates active liquidity.
     * @param onBehalfOf Address of the entity on whose behalf the liquidity repayment is made.
     * @return amountXAssets Repayment amount for asset X.
     * @return amountYAssets Repayment amount for asset Y.
     * @return repayAmountLShares Amount of liquidity repaid.
     */
    function repayLiquidity(
        address onBehalfOf
    ) external returns (uint256 amountXAssets, uint256 amountYAssets, uint256 repayAmountLShares);

    /**
     * @notice Transfers excess tokens to a specified address.
     * @dev Calculates the excess of tokenX and tokenY balances and transfers them to the specified address.
     * @param to The address to which the excess tokens are transferred.
     */
    function skim(
        address to
    ) external;

    /**
     * @notice Updates the reserves to match the current token balances.
     * @dev Reads the current balance of tokenX and tokenY in the contract, and updates the reserves to match these balances.
     */
    function sync() external;
}
