pragma solidity >=0.4.24;

// inherited contracts
import './corsOwn/Ownable.sol';
import './roles/FarmerRole.sol';
import './roles/DistributorRole.sol';
import './roles/RetailerRole.sol';
import './roles/ConsumerRole.sol';


// Define a contract 'Supplychain'
contract Supplychain is Ownable, FarmerRole, DistributorRole, RetailerRole, ConsumerRole {

    // Define 'owner'
    address owner;

    // Define a variable called 'upc' for Universal Product Code (UPC)
    uint public upc;

    // Define a variable called 'sku' for Stock Keeping Unit (SKU)
    uint public sku = 0;

    // Define a public mapping 'items' that maps the UPC to an Item.
    mapping (uint => Item) items;

    // Define a public mapping 'itemsHistory' that maps the UPC to an array of TxHash,
    // that track its journey through the supply chain -- to be sent from DApp.
    mapping (uint => Txblocks) productHistory;

    // Define enum 'State' with the following values:
    enum State
    {
        ProduceByFarmer,         // 0
        ForSaleByFarmer,         // 1
        PurchasedByDistributor,  // 2
        ShippedByFarmer,         // 3
        ReceivedByDistributor,   // 4
        ProcessedByDistributor,  // 5
        PackageByDistributor,    // 6
        ForSaleByDistributor,    // 7
        PurchasedByRetailer,     // 8
        ShippedByDistributor,    // 9
        ReceivedByRetailer,      // 10
        ForSaleByRetailer,       // 11
        PurchasedByConsumer      // 12
    }


    State constant defaultState = State.ProduceByFarmer;

    // Define a struct 'Item' with the following fields:
    struct Item {
        uint    sku;                    // Stock Keeping Unit (SKU)
        uint    upc;                    // Universal Product Code (UPC), generated by the Farmer, goes on the package, can be verified by the Consumer
        address ownerID;                // Metamask-Ethereum address of the current owner as the product moves through 8 stages
        address farmerID;               // Metamask-Ethereum address of the Farmer // ADDED PAYABLE
        bytes32 farmID;
        string  farmName;
        string  farmInformation;
        string  farmLatitude;
        string  farmLongitude;
        bytes32  productId;
        string  productNotes;
        uint256 productDate;
        uint    productPrice;
        uint    productSliced;
        State   itemState;              // Product State as represented in the enum above
        address distributorID;
        address retailerID;
        address consumerID;
    }

    // Block number stuct
    struct Txblocks {
        uint FTD;
        uint DTR;
        uint RTC;
    }


    event ProduceByFarmer(uint upc);         //1
    event ForSaleByFarmer(uint upc);         //2
    event PurchasedByDistributor(uint upc);  //3
    event ShippedByFarmer(uint upc);         //4
    event ReceivedByDistributor(uint upc);   //5
    event ProcessedByDistributor(uint upc);  //6
    event PackagedByDistributor(uint upc);   //7
    event ForSaleByDistributor(uint upc);    //8
    event PurchasedByRetailer(uint upc);     //9
    event ShippedByDistributor(uint upc);    //10
    event ReceivedByRetailer(uint upc);      //11
    event ForSaleByRetailer(uint upc);       //12
    event PurchasedByConsumer(uint upc);     //13


    // Define a modifer that checks to see if msg.sender == owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Define a modifer that verifies the Caller
    modifier verifyCaller (address _address) {
        require(msg.sender == _address);
        _;
    }

    // Define a modifier that checks if the paid amount is sufficient to cover the price
    modifier paidEnough(uint _price) {
        require(msg.value >= _price);
        _;
    }

    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(uint _upc, address payable addressToFund) {
        uint _price = items[_upc].productPrice;
        uint  amountToReturn = msg.value - _price;
        addressToFund.transfer(amountToReturn);
        _;
    }

    //Item State Modifiers
    modifier producedByFarmer(uint _upc) {
        require(items[_upc].itemState == State.ProduceByFarmer);
        _;
    }

    modifier forSaleByFarmer(uint _upc) {
        require(items[_upc].itemState == State.ForSaleByFarmer);
        _;
    }

    modifier purchasedByDistributor(uint _upc) {
        require(items[_upc].itemState == State.PurchasedByDistributor);
        _;
    }

    modifier shippedByFarmer(uint _upc) {
        require(items[_upc].itemState == State.ShippedByFarmer);
        _;
    }

    modifier receivedByDistributor(uint _upc) {
        require(items[_upc].itemState == State.ReceivedByDistributor);
        _;
    }

    modifier processByDistributor(uint _upc) {
        require(items[_upc].itemState == State.ProcessedByDistributor);
        _;
    }

    modifier packagedByDistributor(uint _upc) {
        require(items[_upc].itemState == State.PackageByDistributor);
        _;
    }

    modifier forSaleByDistributor(uint _upc) {
        require(items[_upc].itemState == State.ForSaleByDistributor);
        _;
    }


    modifier shippedByDistributor(uint _upc) {
        require(items[_upc].itemState == State.ShippedByDistributor);
        _;
    }

    modifier purchasedByRetailer(uint _upc) {
        require(items[_upc].itemState == State.PurchasedByRetailer);
        _;
    }

    modifier receivedByRetailer(uint _upc) {
        require(items[_upc].itemState == State.ReceivedByRetailer);
        _;
    }

    modifier forSaleByRetailer(uint _upc) {
        require(items[_upc].itemState == State.ForSaleByRetailer);
        _;
    }

    modifier purchasedByConsumer(uint _upc) {
        require(items[_upc].itemState == State.PurchasedByConsumer);
        _;
    }

    // constructor setup owner sku upc
    constructor() public payable {
        owner = msg.sender;
        sku = 1;
        upc = 1;
    }

    // Define a function 'kill'
    function kill() public {
        if (msg.sender == owner) {
            address payable ownerAddressPayable = _make_payable(owner);
            selfdestruct(ownerAddressPayable);
        }
    }


    // allows you to convert an address into a payable address
    function _make_payable(address x) internal pure returns (address payable) {
        return address(uint160(x));
    }

    /*
    * 1st step in supplychain
    */
    function createProductByFarmer (
        uint _upc,
        uint _price,
        string memory _productNotes,
        string memory _originFarmName,
        string memory _originFarmInformation,
        string memory _originFarmLatitude,
        string memory _originFarmLongitude
    ) public onlyFarmer() // check address belongs to farmerRole
    {
        address distributorID; // Empty distributorID address
        address retailerID; // Empty retailerID address
        address consumerID; // Empty consumerID address
        Item memory newProduce; // Create a new struct Item in memory
        newProduce.sku = sku;  // Stock Keeping Unit (SKU)
        newProduce.upc = _upc; // Universal Product Code (UPC), generated by the Farmer, goes on the package, can be verified by the Consumer
        newProduce.ownerID = msg.sender;  // Metamask-Ethereum address of the current owner as the product moves through 8 stages
        newProduce.farmerID = msg.sender; // Metamask-Ethereum address of the Farmer
        newProduce.farmID = keccak256(abi.encodePacked(now, _originFarmName));
        newProduce.farmName = _originFarmName;  // Farmer Name
        newProduce.farmInformation = _originFarmInformation; // Farmer Information
        newProduce.farmLatitude = _originFarmLatitude; // Farm Latitude
        newProduce.farmLongitude = _originFarmLongitude;  // Farm Longitude
        newProduce.productId = keccak256(abi.encodePacked(now, msg.sender));  // Product ID
        newProduce.productNotes = _productNotes; // Product Notes
        newProduce.productPrice = _price;  // Product Price
        newProduce.productSliced = 0;
        newProduce.productDate = now;
        newProduce.itemState = defaultState; // Product State as represented in the enum above
        newProduce.distributorID = distributorID; // Metamask-Ethereum address of the Distributor
        newProduce.retailerID = retailerID; // Metamask-Ethereum address of the Retailer
        newProduce.consumerID = consumerID; // Metamask-Ethereum address of the Consumer // ADDED payable
        items[_upc] = newProduce; // Add newProduce to items struct by upc

        uint placeholder; // Block number place holder
        Txblocks memory txBlock; // create new txBlock struct
        txBlock.FTD = placeholder; // assign placeholder values
        txBlock.DTR = placeholder;
        txBlock.RTC = placeholder;
        productHistory[_upc] = txBlock; // add txBlock to itemsHistory mapping by upc

        // Increment sku
        sku = sku + 1;

        // Emit the appropriate event
        emit ProduceByFarmer(_upc);

    }

    /*
    2nd step in supplychain
    Allows farmer to sell saffron
    */
    function sellProductByFarmer(uint _upc, uint _price) public onlyFarmer() // check msg.sender belongs to farmerRole
    producedByFarmer(_upc) // check items state has been produced
    verifyCaller(items[_upc].ownerID) // check msg.sender is owner
    {
        items[_upc].itemState = State.ForSaleByFarmer;
        items[_upc].productPrice = _price;
        emit ForSaleByFarmer(_upc);
    }

    /*
    3rd step in supplychain
    Allows distributor to purchase saffron
    */
    function purchaseProductByDistributor(uint _upc) public payable onlyDistributor() // check msg.sender belongs to distributorRole
    forSaleByFarmer(_upc) // check items state is for ForSaleByFarmer
    paidEnough(items[_upc].productPrice) // check if distributor sent enough Ether for saffron
    checkValue(_upc, msg.sender) // check if overpaid return remaining funds back to msg.sender
    {
        address payable ownerAddressPayable = _make_payable(items[_upc].farmerID); // make originFarmID payable
        ownerAddressPayable.transfer(items[_upc].productPrice); // transfer funds from distributor to farmer
        items[_upc].ownerID = msg.sender; // update owner
        items[_upc].distributorID = msg.sender; // update distributor
        items[_upc].itemState = State.PurchasedByDistributor; // update state
        productHistory[_upc].FTD = block.number; // add block number
        emit PurchasedByDistributor(_upc);
    }

    /*
    4th step in supplychain
    Allows farmer to ship saffron purchased by distributor
    */
    function shipProductByFarmer(uint _upc) public payable onlyFarmer() // check msg.sender belongs to FarmerRole
    purchasedByDistributor(_upc)
    verifyCaller(items[_upc].farmerID) // check msg.sender is originFarmID
    {
        items[_upc].itemState = State.ShippedByFarmer; // update state
        emit ShippedByFarmer(_upc);
    }

    /*
    5th step in supplychain
    Allows distributor to receive saffron
    */
    function receiveProductByDistributor(uint _upc) public onlyDistributor() // check msg.sender belongs to DistributorRole
    shippedByFarmer(_upc) verifyCaller(items[_upc].ownerID) // check msg.sender is owner
    {
        items[_upc].itemState = State.ReceivedByDistributor; // update state
        emit ReceivedByDistributor(_upc);
    }

    /*
    6th step in supplychain
    Allows distributor to process saffron
    */
    function processProductByDistributor(uint _upc, uint slices) public  onlyDistributor() // check msg.sender belongs to DistributorRole
    receivedByDistributor(_upc)  verifyCaller(items[_upc].ownerID) // check msg.sender is owner
    {
        items[_upc].itemState = State.ProcessedByDistributor; // update state
        items[_upc].productSliced = slices;
        emit ProcessedByDistributor(_upc);
    }

    /*
    7th step in supplychain
    Allows distributor to package saffron
    */
    function packageProductByDistributor(uint _upc) public onlyDistributor() // check msg.sender belongs to DistributorRole
    processByDistributor(_upc) verifyCaller(items[_upc].ownerID) // check msg.sender is owner
    {
        items[_upc].itemState = State.PackageByDistributor;
        emit PackagedByDistributor(_upc);
    }

    /*
    8th step in supplychain
    Allows distributor to sell saffron
    */
    function sellProductByDistributor(uint _upc, uint _price) public onlyDistributor() // check msg.sender belongs to DistributorRole
    packagedByDistributor(_upc) verifyCaller(items[_upc].ownerID) // check msg.sender is owner
    {
        items[_upc].itemState = State.ForSaleByDistributor;
        items[_upc].productPrice = _price;
        emit ForSaleByDistributor(upc);
    }

    /*
    9th step in supplychain
    Allows retailer to purchase saffron
    */
    function purchaseProductByRetailer(uint _upc) public payable onlyRetailer() // check msg.sender belongs to RetailerRole
    forSaleByDistributor(_upc) paidEnough(items[_upc].productPrice)
    checkValue(_upc, msg.sender)
    {
        address payable ownerAddressPayable = _make_payable(items[_upc].distributorID);
        ownerAddressPayable.transfer(items[_upc].productPrice);
        items[_upc].ownerID = msg.sender;
        items[_upc].retailerID = msg.sender;
        items[_upc].itemState = State.PurchasedByRetailer;
        productHistory[_upc].DTR = block.number;
        emit PurchasedByRetailer(_upc);
    }

    /*
    10th step in supplychain
    Allows Distributor to ship Saffron
    */
    function shipProductByDistributor(uint _upc) public onlyDistributor() // check msg.sender belongs to DistributorRole
    purchasedByRetailer(_upc) verifyCaller(items[_upc].distributorID) // check msg.sender is distributorID
    {
        items[_upc].itemState = State.ShippedByDistributor;
        emit ShippedByDistributor(_upc);
    }

    /*
    11th step in supplychain
    */
    function receiveProductByRetailer(uint _upc) public onlyRetailer() // check msg.sender belongs to RetailerRole
    shippedByDistributor(_upc) verifyCaller(items[_upc].ownerID) // check msg.sender is ownerID
    {
        items[_upc].itemState = State.ReceivedByRetailer;
        emit ReceivedByRetailer(_upc);
    }

    /*
    12th step in supplychain
    */
    function sellProductByRetailer(uint _upc, uint _price) public onlyRetailer()  // check msg.sender belongs to RetailerRole $
    receivedByRetailer(_upc) verifyCaller(items[_upc].ownerID) // check msg.sender is ownerID
    {
        items[_upc].itemState = State.ForSaleByRetailer;
        items[_upc].productPrice = _price;
        emit ForSaleByRetailer(_upc);
    }

    /*
    13th step in supplychain
    */
    function purchaseProductByConsumer(uint _upc) public payable onlyConsumer()  // check msg.sender belongs to ConsumerRole
    forSaleByRetailer(_upc)  paidEnough(items[_upc].productPrice) checkValue(_upc, msg.sender) {
        items[_upc].consumerID = msg.sender;
        address payable ownerAddressPayable = _make_payable(items[_upc].retailerID);
        ownerAddressPayable.transfer(items[_upc].productPrice);
        items[_upc].ownerID = msg.sender;
        items[_upc].consumerID = msg.sender;
        items[_upc].itemState = State.PurchasedByConsumer;
        productHistory[_upc].RTC = block.number;
        emit PurchasedByConsumer(_upc);
    }

    // Define a function 'fetchItemBufferOne' that fetches the data
    function getItemBufferOne(uint _upc) public view returns
    (
        uint    itemSKU,
        uint    itemUPC,
        address ownerID,
        address farmerID,
        bytes32 farmId,
        string memory  farmName,
        string memory farmInformation,
        string memory farmLatitude,
        string memory farmLongitude,
        uint productDate,
        uint productSliced
    )
    {
        // Assign values to the 8 parameters
        Item memory item = items[_upc];
        return (
            item.sku,
            item.upc,
            item.ownerID,
            item.farmerID,
            item.farmID,
            item.farmName,
            item.farmInformation,
            item.farmLatitude,
            item.farmLongitude,
            item.productDate,
            productSliced
        );
    }

    // Define a function 'fetchItemBufferTwo' that fetches the data
    function getItemBufferTwo(uint _upc) public view returns
    (
        uint    itemSKU,
        uint    itemUPC,
        bytes32    productId,
        string  memory productNotes,
        uint    productPrice,
        uint256 productDate,
        State   itemState,
        address distributorID,
        address retailerID,
        address consumerID
    )
    {
        // Assign values to the 9 parameters
        Item memory item = items[_upc];
        return
        (
            item.sku,
            item.upc,
            item.productId,
            item.productNotes,
            item.productPrice,
            item.productDate,
            item.itemState,
            item.distributorID,
            item.retailerID,
            item.consumerID
        );

    }

    // Define a function 'fetchItemHistory' that fetaches the data
    function fetchProductHistory(uint _upc) public view returns
    (
        uint blockFarmerToDistributor,
        uint blockDistributorToRetailer,
        uint blockRetailerToConsumer
    )
    {
        // Assign value to the parameters
        Txblocks memory txblock = productHistory[_upc];
        return
        (
            txblock.FTD,
            txblock.DTR,
            txblock.RTC
        );

    }

}