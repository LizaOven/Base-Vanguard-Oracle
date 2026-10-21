// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IVanguardOracleVault {
    function depositCollateral(bytes32 assetId) external payable;
    function executeLiquidation(address targetUser) external;
    function fetchHealthFactor(address user) external view returns (uint256);
}
