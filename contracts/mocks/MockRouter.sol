// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function approve(address,uint256) external returns (bool);
    function mint(address,uint256) external;
}

contract MockRouter {
    // 简化：1:1 兑换（忽略最小滑点），只要有授权，就把 path[0] 的全部换成 path[end]
    function swapExactTokensForTokens(
        uint amountIn,
        uint /*amountOutMin*/,
        address[] calldata path,
        address to,
        uint /*deadline*/
    ) external returns (uint[] memory amounts) {
        address from = path[0];
        address toToken = path[path.length - 1];

        // 扣调用者的 fromToken
        IERC20Like(from).transferFrom(msg.sender, address(this), amountIn);
        // 给目标地址铸造等量 toToken（模拟路由换出）
        IERC20Like(toToken).mint(to, amountIn);

        amounts = new uint[](path.length);
        amounts[0] = amountIn; amounts[path.length-1] = amountIn;
    }
}
