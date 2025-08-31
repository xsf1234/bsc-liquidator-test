// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IFlashCallee {
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}

contract MockPancakeV3Pool {
    address public token0;
    address public token1;
    uint256 public feeBps0 = 5; // 0.05% 模拟
    uint256 public feeBps1 = 5; // 0.05%

    constructor(address _t0, address _t1) { token0 = _t0; token1 = _t1; }

    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (amount0 > 0) _transfer(token0, recipient, amount0);
        if (amount1 > 0) _transfer(token1, recipient, amount1);

        uint256 fee0 = amount0 * feeBps0 / 10000;
        uint256 fee1 = amount1 * feeBps1 / 10000;

        IFlashCallee(recipient).pancakeV3FlashCallback(fee0, fee1, data);

        // 回款校验
        uint256 need0 = amount0 + fee0;
        uint256 need1 = amount1 + fee1;
        require(_balance(token0, address(this)) >= need0, "repay0");
        require(_balance(token1, address(this)) >= need1, "repay1");
    }

    function _transfer(address t, address to, uint256 amt) internal {
        (bool ok, ) = t.call(abi.encodeWithSignature("transfer(address,uint256)", to, amt));
        require(ok, "t.transfer");
    }
    function _balance(address t, address a) internal view returns (uint256) {
        (bool ok, bytes memory ret) = t.staticcall(abi.encodeWithSignature("balanceOf(address)", a));
        require(ok, "t.balance"); return abi.decode(ret,(uint256));
    }
}
