// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IAccessControlEnumerable, AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {TalentToken} from "./TalentToken.sol";

interface ITalentFactory {
    /// Returns true is a given address corresponds to a registered Talent Token
    ///
    /// @param addr address of the token to find
    /// @return true if the address corresponds to a talent token
    function isTalentToken(address addr) external view returns (bool);

    /// Returns true is a given symbol corresponds to a registered Talent Token
    ///
    /// @param symbol Symbol of the token to find
    /// @return true if the symbol corresponds to an existing talent token
    function isSymbol(string memory symbol) external view returns (bool);
}

/// @title Factory in charge of deploying Talent Token contracts
///
/// @notice This contract relies on ERC1167 proxies to cheaply deploy talent tokens
///
/// @notice Roles:
///   A minter role defines who is allowed to deploy talent tokens. Deploying
///   a talent token grants you the right to mint that talent token, meaning the
///   same deployer will be granted that role
contract TalentFactory is ERC165, AccessControlEnumerable, ITalentFactory {
    /// creator role
    bytes32 public constant ROLE_MINTER = keccak256("MINTER");

    /// initial supply of each new token minted
    uint256 public constant INITIAL_SUPPLY = 1000 ether;

    /// maps each talent's address to their talent token
    mapping(address => address) public talentsToTokens;

    /// maps each talent tokens' address to their talent
    mapping(address => address) public tokensToTalents;

    /// maps each token's symbol to the token address
    mapping(string => address) public symbolsToTokens;

    /// minter for new tokens
    address public minter;

    /// implementation template to clone
    /// TODO ability to update implementation for new talent tokens
    address public immutable implementation;

    event TalentCreated(address indexed talent, address indexed token);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        implementation = address(new TalentToken());
    }

    function setMinter(address _minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minter == address(0x0), "minter already set");

        minter = _minter;
        _setupRole(ROLE_MINTER, _minter);
    }

    /// Creates a new talent token
    ///
    /// @param _talent The talent's address
    /// @param _name The new token's name
    /// @param _symbol The new token's symbol
    function createTalent(
        address _talent,
        string memory _name,
        string memory _symbol
    ) public returns (address) {
        require(!isSymbol(_symbol), "talent token with this symbol already exists");
        require(_isMinterSet(), "minter not yet set");

        address token = Clones.clone(implementation);
        TalentToken(token).initialize(
            _name,
            _symbol,
            INITIAL_SUPPLY,
            _talent,
            minter,
            getRoleMember(DEFAULT_ADMIN_ROLE, 0)
        );

        symbolsToTokens[_symbol] = token;
        tokensToTalents[token] = _talent;

        emit TalentCreated(_talent, token);

        return token;
    }

    //
    // Begin: ERC165
    //

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, AccessControlEnumerable)
        returns (bool)
    {
        return AccessControlEnumerable.supportsInterface(interfaceId);
    }

    //
    // End: ERC165
    //

    //
    // Begin: ITalentFactory
    //

    function isTalentToken(address addr) public view override(ITalentFactory) returns (bool) {
        return tokensToTalents[addr] != address(0x0);
    }

    function isSymbol(string memory _symbol) public view override(ITalentFactory) returns (bool) {
        return symbolsToTokens[_symbol] != address(0x0);
    }

    //
    // End: ITalentFactory
    //

    function _isMinterSet() private view returns (bool) {
        return minter != address(0x0);
    }
}
