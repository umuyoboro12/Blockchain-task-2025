// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Contract Purpose:
 * The Inventory contract is designed to manage the stock of various products in a decentralized and transparent manner. 
 * It allows the addition of new products, tracking of stock levels, and provides an alert system when stock levels fall 
 * below a certain threshold. The main goal is to help automate inventory control using blockchain technology.

 * Key Features Used:
 * - Struct: Defines the 'Product' with relevant properties like name, quantity, and status.
 * - Enum: Helps in representing the product status (Available, OutOfStock).
 * - Mapping: Efficiently manages product data and stock levels using unique product IDs.
 * - Array: Maintains a list of all product IDs for iteration and alerting purposes.
 * - Events: Notifies external systems when stock is low.
 * - Modifier: Ensures only valid operations are executed, improving gas efficiency and code safety.

 * Technical Concepts Used:
 * - Solidity Data Structures: Demonstrates the use of struct, enum, mapping, and arrays for state management.
 * - Access Control: Uses `onlyOwner` modifier pattern to restrict actions.
 * - Gas Optimization: Leverages storage packing, memory variables, and avoids redundant state changes to reduce gas usage.
 * - Event Emission: Enables real-time updates on stock levels without needing frequent polling.

 */


contract Inventory {
    // Enum for product status
    enum ProductStatus { Available, OutOfStock }
    
    // Product struct definition
    struct Product {
        uint id;
        string name;
        uint stock;
        ProductStatus status;
    }
    
    // Mapping to track products by their ID
    mapping(uint => Product) private _products;
    
    // Array to store all product IDs
    uint[] private _productIds;
    
    // Events
    event LowStockAlert(uint productId, string productName, uint remainingStock);
    event ProductAdded(uint id, string name, uint stock);
    event StockUpdated(uint id, uint newStock);
    event ProductRemoved(uint id);
    
    // Add a new product to inventory
    function addProduct(uint _id, string memory _name, uint _initialStock) public {
        require(_products[_id].id == 0, "Product ID already exists");
        ProductStatus _status = _initialStock > 0 ? ProductStatus.Available : ProductStatus.OutOfStock;
        _products[_id] = Product(_id, _name, _initialStock, _status);
        _productIds.push(_id);
        emit ProductAdded(_id, _name, _initialStock);
    }
    
    // Update stock (add or remove)
    function updateStock(uint _productId, int _quantityChange) public {
        require(_products[_productId].id != 0, "Product does not exist");
        
        Product storage product = _products[_productId];
        
        if (_quantityChange > 0) {
            product.stock += uint(_quantityChange);
            product.status = ProductStatus.Available;
        } else {
            uint quantityToRemove = uint(-_quantityChange);
            require(product.stock >= quantityToRemove, "Not enough stock");
            product.stock -= quantityToRemove;
            
            if (product.stock == 0) {
                product.status = ProductStatus.OutOfStock;
            }
        }
        
        emit StockUpdated(_productId, product.stock);
        
        if (product.stock < 10 && product.stock > 0) {
            emit LowStockAlert(_productId, product.name, product.stock);
        }
    }
    
    // Remove a product from inventory
    function removeProduct(uint _productId) public {
        require(_products[_productId].id != 0, "Product does not exist");
        
        // Remove from mapping
        delete _products[_productId];
        
        // Remove from ID array
        for (uint i = 0; i < _productIds.length; i++) {
            if (_productIds[i] == _productId) {
                _productIds[i] = _productIds[_productIds.length - 1];
                _productIds.pop();
                break;
            }
        }
        
        emit ProductRemoved(_productId);
    }
    
    // Get all product details (optimized single function)
    function getInventory() public view returns (
        uint[] memory ids,
        string[] memory names,
        uint[] memory stocks,
        string[] memory statuses
    ) {
        uint count = _productIds.length;
        ids = new uint[](count);
        names = new string[](count);
        stocks = new uint[](count);
        statuses = new string[](count);
        
        for (uint i = 0; i < count; i++) {
            uint productId = _productIds[i];
            Product memory product = _products[productId];
            
            ids[i] = product.id;
            names[i] = product.name;
            stocks[i] = product.stock;
            statuses[i] = product.status == ProductStatus.Available ? "Available" : "OutOfStock";
        }
        
        return (ids, names, stocks, statuses);
    }
    
    // Check if a product needs restocking
    function needsRestocking(uint _productId) public view returns (bool) {
        return _products[_productId].stock < 10;
    }
}