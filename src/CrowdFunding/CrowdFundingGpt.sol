// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CrowdFundingGpt (версия от gpt)
 * @notice Краудфандинг под ERC20 с автосозданием вестинга при достижении цели.
 */
contract CrowdFundingGpt is IUtilityContract, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --------- параметры кампании (immutable) ----------
    uint256 public immutable goal;
    address public immutable fundraiser;
    uint256 public immutable duration;

    // --------- настраивается через initialize(...) ----------
    IERC20  public token;
    address public vestingWallet; // имплементация для клонов

    // --------- состояние кампании ----------
    address payable public vesting; // адрес созданного вестинга
    uint256 public liveAmount;      // собранные средства до финализации
    bool    public finalized;       // true после перевода средств в вестинг
    bool    private initialized;    // защита повторной initialize

    // История вкладов
    mapping(address => uint256) public userVested;

    // --------- ошибки ----------
    error AlreadyInitialized();
    error NotInitialized();
    error InvalidVestingImplementation();
    error OnlyFundraiserCanWithdraw();
    error TransferFailed();
    error GoalReached();
    error GoalNotReached();
    error InvalidAmount();
    error Finalized();

    // --------- события ----------
    event AmountContributed(address indexed user, uint256 amount, uint256 timestamp);
    event AmountRefunded(address indexed user, uint256 amount, uint256 timestamp);
    event VestingCreated(address indexed vesting, address indexed fundraiser, uint256 goal, uint256 duration, uint256 timestamp);
    event CampaignFinalized(address indexed vesting, uint256 total, uint256 timestamp);

    // --------- модификаторы ----------
    modifier notInitialized() {
        if (initialized) revert AlreadyInitialized();
        _;
    }

    modifier needInitialize() {
        if (!initialized) revert NotInitialized();
        _;
    }

    // --------- конструктор ----------
    constructor(
        uint256 _goal,
        address _fundraiser,
        uint256 _duration
    ) Ownable(msg.sender) {
        goal = _goal;
        fundraiser = _fundraiser;
        duration = _duration;
    }

    // --------- пользовательские действия ----------

    /// @notice Внести токены (ERC20). ETH не принимается.
    function contribute(uint256 _amount)
        external
        needInitialize
        nonReentrant
        returns (address)
    {
        if (finalized) revert Finalized();
        if (_amount == 0) revert InvalidAmount();

        token.safeTransferFrom(msg.sender, address(this), _amount);

        liveAmount += _amount;
        userVested[msg.sender] += _amount;

        emit AmountContributed(msg.sender, _amount, block.timestamp);

        // Достигли цели — создаём вестинг и переводим всё собранное
        if (liveAmount >= goal) {
            if (vestingWallet == address(0)) revert InvalidVestingImplementation();

            address _vesting = Clones.clone(vestingWallet);
            vesting = payable(_vesting);

            bool ok = IUtilityContract(vesting).initialize(getInitDataToVesting());
            if (!ok) revert InvalidVestingImplementation();

            uint256 total = liveAmount;
            token.safeTransfer(vesting, total);

            // Обнуляем локальный счётчик — на контракте больше нет токенов кампании
            liveAmount = 0;
            finalized = true;

            emit VestingCreated(vesting, fundraiser, goal, duration, block.timestamp);
            emit CampaignFinalized(vesting, total, block.timestamp);

            return vesting;
        }

        return address(0);
    }

    /// @notice Рефанд до достижения цели.
    function refund(uint256 _amount)
        external
        needInitialize
        nonReentrant
    {
        if (finalized) revert GoalReached();
        if (liveAmount >= goal) revert GoalReached();
        if (_amount == 0) revert InvalidAmount();

        uint256 vested = userVested[msg.sender];
        if (vested < _amount) revert InvalidAmount();

        userVested[msg.sender] = vested - _amount;
        liveAmount -= _amount;

        token.safeTransfer(msg.sender, _amount);

        emit AmountRefunded(msg.sender, _amount, block.timestamp);
    }

    /// @notice Триггерит release в вестинге (если поддерживается).
    function withdraw()
        external
        needInitialize
        nonReentrant
    {
        if (msg.sender != fundraiser && msg.sender != owner()) {
            revert OnlyFundraiserCanWithdraw();
        }
        if (!finalized || vesting == address(0)) revert GoalNotReached();

        (bool success, ) = vesting.call(
            abi.encodeWithSignature("release(address)", address(token))
        );
        if (!success) revert TransferFailed();
    }

    // --------- хелперы и initialize ----------

    /// @notice Данные для инициализации клон-вестинга: (beneficiary=fundraiser, start=now, duration)
    function getInitDataToVesting() public view returns (bytes memory) {
        return abi.encode(fundraiser, uint64(block.timestamp), duration);
    }

    /// @notice Данные для инициализации этого контракта: (owner, token, vestingWallet)
    function getInitData(address _owner, address _token, address _vestingWallet)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_owner, _token, _vestingWallet);
    }

    /// @notice Одноразовая инициализация (через фабрику/деплойер).
    function initialize(bytes memory _initData)
        external
        notInitialized
        returns (bool)
    {
        (address _owner, address _token, address _vestingWallet) =
            abi.decode(_initData, (address, address, address));

        Ownable.transferOwnership(_owner);
        token = IERC20(_token);
        vestingWallet = _vestingWallet;

        initialized = true;
        return true;
    }
}
