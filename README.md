# Base Vanguard Oracle Vault

A highly secure, data-driven DeFi vault deployed on the Base network. Vanguard Oracle Vault manages user collateral and debt positions by actively consuming decentralized price feeds, ensuring that platform solvency is maintained through automated, math-backed liquidation thresholds.

## Security & Oracle Mechanics
* **Price Staleness Protection:** Integrates strict heartbeat checks. If the underlying oracle fails to update within the accepted `block.timestamp` window, the vault automatically halts new debt issuance to prevent undercollateralization.
* **Automated Liquidation Engine:** Maintains public keeper-compatible endpoints. If a position's Health Factor drops below `1.0`, external liquidators can instantly clear the debt and claim the liquidation penalty.
* **Flash-Loan Resistance:** Implements time-weighted average price (TWAP) sanity checks alongside standard spot pricing to heavily mitigate the risk of flash-loan oracle manipulation attacks.

## Architecture
Built with Solidity `0.8.37`. The protocol emphasizes mathematical precision, utilizing high-scale fixed-point arithmetic (`1e18` precision) for all health factor and collateralization ratio calculations.
