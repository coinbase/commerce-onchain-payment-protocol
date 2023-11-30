// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @title Sweepable contract
// @notice Implements a role that can sweep stuck funds to an address provided
//   at the time of the call
abstract contract Sweepable is Context, Ownable {
    using SafeERC20 for IERC20;

    // @dev The address of the current sweeper
    address private _sweeper;

    // @dev Restricts the caller to the current sweeper
    modifier onlySweeper() {
        require(sweeper() == _msgSender(), "Sweepable: not the sweeper");
        _;
    }

    modifier notZero(address a) {
        require(a != address(0), "Sweepable: cannot be zero address");
        _;
    }

    // @dev Returns the current sweeper
    function sweeper() public view virtual returns (address) {
        return _sweeper;
    }

    // @dev Sets the sweeper
    // @notice To remove the sweeper role entirely, set this to the zero address.
    function setSweeper(address newSweeper) public virtual onlyOwner notZero(newSweeper) {
        _sweeper = newSweeper;
    }

    // @dev Sweeps the entire ETH balance to `destination`
    function sweepETH(address payable destination) public virtual onlySweeper notZero(destination) {
        uint256 balance = address(this).balance;
        require(balance > 0, "Sweepable: zero balance");
        (bool success, ) = destination.call{value: balance}("");
        require(success, "Sweepable: transfer error");
    }

    // @dev Sweeps a specific ETH `amount` to `destination`
    function sweepETHAmount(address payable destination, uint256 amount)
        public
        virtual
        onlySweeper
        notZero(destination)
    {
        uint256 balance = address(this).balance;
        require(balance >= amount, "Sweepable: insufficient balance");
        (bool success, ) = destination.call{value: amount}("");
        require(success, "Sweepable: transfer error");
    }

    // @dev Sweeps the entire token balance to `destination`
    function sweepToken(address _token, address destination) public virtual onlySweeper notZero(destination) {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Sweepable: zero balance");
        token.safeTransfer(destination, balance);
    }

    // @dev Sweeps a specific token `amount` to `destination`
    function sweepTokenAmount(
        address _token,
        address destination,
        uint256 amount
    ) public virtual onlySweeper notZero(destination) {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Sweepable: insufficient balance");
        token.safeTransfer(destination, amount);
    }
}
