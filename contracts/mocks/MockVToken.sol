// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 { 
    function balanceOf(address) external view returns (uint256);
    function transfer(address to,uint256 amount) external returns (bool);
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
    function approve(address spender,uint256 amount) external returns (bool);
}

contract MockVToken {
    address public underlying;          // 对应你的 vToken.underlying()
    uint256 public exchangeRate = 1e18; // 简化：1 vToken = 1 underlying

    mapping(address => uint256) public balanceOf;

    constructor(address _underlying) { underlying = _underlying; }

    // 简化版：清算时“偿还债务”即直接从清算合约收下 debt 资产，然后奖励一些 vToken
    function liquidateBorrow(address /*borrower*/, uint repayAmount, address vTokenCollateral) external returns (uint) {
        // 从调用者把 debt token 转给本合约（由外部先 approve）
        // 这里不检查资产种类，做最小可行模拟
        IERC20(underlying).transferFrom(msg.sender, address(this), repayAmount);
        // 奖励：给调用者一些抵押 vToken（模拟 seize）
        MockVToken(vTokenCollateral).mint(msg.sender, repayAmount); // 1:1 简化
        return 0;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function redeem(uint redeemTokens) external returns (uint) {
        require(balanceOf[msg.sender] >= redeemTokens, "no v");
        balanceOf[msg.sender] -= redeemTokens;
        // 按 1:1 赎回 underlying，给调用者
        IERC20(underlying).transfer(msg.sender, redeemTokens);
        return 0;
    }
}
