pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

// SPDX-License- Identifier: MIT

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract Rando is OFT {
    constructor(
    ) OFT("Rando", "RANDO", 0x6EDCE65403992e310A62460808c4b910D972f10f, msg.sender) Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}