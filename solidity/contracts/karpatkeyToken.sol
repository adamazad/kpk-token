// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import {IkarpatkeyToken} from 'interfaces/IkarpatkeyToken.sol';

contract karpatkeyToken is
  Initializable,
  IkarpatkeyToken,
  ERC20Upgradeable,
  PausableUpgradeable,
  OwnableUpgradeable,
  ERC20PermitUpgradeable,
  ERC20VotesUpgradeable
{
  mapping(address account => uint256) private _transferAllowances;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address initialOwner) public initializer {
    __ERC20_init('karpatkey Token', 'KPK');
    __ERC20Permit_init('karpatkey Token');
    __ERC20Votes_init();
    __Ownable_init(initialOwner);
    _mint(initialOwner, 1_000_000 * 10 ** decimals());
    _pause();
    _approveTransfer(initialOwner, type(uint256).max); // For the transferFrom method where the 'from' address is the initialOnwer
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  /**
   * @dev See {IERC20-transfer}.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - the caller must have a balance of at least `value`.
   */
  function transferByOwner(address from, address to, uint256 value) public virtual onlyOwner returns (bool) {
    _transfer(from, to, value);
    return true;
  }

  /// @inheritdoc IkarpatkeyToken
  function transferAllowance(address owner) public view virtual returns (uint256) {
    return _transferAllowances[owner];
  }

  /// @inheritdoc IkarpatkeyToken
  function approveTransfer(address owner, uint256 value) public virtual onlyOwner {
    if (!paused()) {
      revert TransferApprovalWhenUnpaused();
    }
    _approveTransfer(owner, value);
  }

  /// @inheritdoc IkarpatkeyToken
  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  /**
   * @dev Destroys a `value` amount of tokens from the token holder 'owner'.
   *
   * See {ERC20-_burn}.
   */
  function burn(address owner, uint256 value) public virtual onlyOwner {
    _burn(owner, value);
  }

  function rescueToken(IERC20 token, address beneficiary, uint256 value) public virtual onlyOwner returns (bool) {
    _rescueToken(token, beneficiary, value);
    return true;
  }

  function nonces(address owner)
    public
    view
    override(IkarpatkeyToken, ERC20PermitUpgradeable, NoncesUpgradeable)
    returns (uint256)
  {
    return super.nonces(owner);
  }

  function _approveTransfer(address owner, uint256 value) internal virtual {
    if (owner == address(0)) {
      revert InvalidTransferApproval(address(0));
    }
    _transferAllowances[owner] = value;
    emit TransferApproval(owner, value);
  }

  function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
    if (to == address(this)) {
      revert TransferToTokenContract();
    }
    if (paused() && owner() != _msgSender()) {
      _spendTransferAllowance(from, value);
    }
    super._update(from, to, value);
  }

  /**
   * @dev Updates `owner` s transfer allowance based on spent `value`.
   *
   * Does not update the transferAllowance value in case of infinite allowance.
   * Revert if not enough transfer allowance is available.
   *
   */
  function _spendTransferAllowance(address owner, uint256 value) internal virtual {
    uint256 currentTransferAllowance = transferAllowance(owner);
    if (currentTransferAllowance != type(uint256).max) {
      if (currentTransferAllowance < value) {
        revert InsufficientTransferAllowance(owner, currentTransferAllowance, value);
      }
      unchecked {
        _approveTransfer(owner, currentTransferAllowance - value);
      }
    }
  }

  function _rescueToken(IERC20 token, address beneficiary, uint256 value) internal virtual {
    uint256 balance = token.balanceOf(address(this));
    if (balance < value) {
      revert InsufficientBalanceToRescue(token, value, balance);
    }
    token.transfer(beneficiary, value);
  }

  function _transferOwnership(address newOwner) internal virtual override(OwnableUpgradeable) {
    if (owner() != address(0)) {
      _approveTransfer(owner(), 0);
    }
    _approveTransfer(newOwner, type(uint256).max);
    super._transferOwnership(newOwner);
  }
}
