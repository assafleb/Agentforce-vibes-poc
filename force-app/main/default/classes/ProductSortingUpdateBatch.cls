/**
 * Batch class for updating Product2 Sorting_Order__c field
 */
public class ProductSortingUpdateBatch implements Database.Batchable<Map<String, String>>, Database.Stateful {
    
    private List<Map<String, String>> dataRows;
    private List<String> headers;
    public List<Map<String, String>> resultsWithStatus { get; set; }
    public Integer successCount { get; set; }
    public Integer failureCount { get; set; }
    
    public ProductSortingUpdateBatch(List<Map<String, String>> dataRows, List<String> headers) {
        this.dataRows = dataRows;
        this.headers = headers;
        this.resultsWithStatus = new List<Map<String, String>>();
        this.successCount = 0;
        this.failureCount = 0;
    }
    
    public Iterable<Map<String, String>> start(Database.BatchableContext bc) {
        return this.dataRows;
    }
    
    public void execute(Database.BatchableContext bc, List<Map<String, String>> scope) {
        // Collect all Product Keys for lookup
        Set<String> productKeys = new Set<String>();
        
        for (Map<String, String> row : scope) {
            String productKey = row.get('Product Key');
            if (String.isNotBlank(productKey)) {
                productKeys.add(productKey);
            }
        }
        
        // Query all matching products using External ID
        Map<String, Product2> productsByKey = new Map<String, Product2>();
        
        try {
            List<Product2> products = [
                SELECT Id, Product_Key__c, Sorting_Order__c
                FROM Product2
                WHERE Product_Key__c IN :productKeys
            ];
            
            for (Product2 prod : products) {
                productsByKey.put(prod.Product_Key__c, prod);
            }
        } catch (Exception e) {
            // Handle query errors
            System.debug('Error querying products: ' + e.getMessage());
        }
        
        // Prepare updates - use Map to deduplicate by Product Id
        Map<Id, Product2> productsToUpdateMap = new Map<Id, Product2>();
        Map<Id, List<Map<String, String>>> rowsByProductId = new Map<Id, List<Map<String, String>>>();
        
        for (Map<String, String> row : scope) {
            String productKey = row.get('Product Key');
            String sortingOrder = row.get('Sorting Order');
            
            Map<String, String> resultRow = new Map<String, String>(row);
            
            if (String.isBlank(productKey)) {
                resultRow.put('Operation Result', 'Fail: Product Key is empty');
                this.resultsWithStatus.add(resultRow);
                this.failureCount++;
                continue;
            }
            
            Product2 product = productsByKey.get(productKey);
            
            if (product == null) {
                resultRow.put('Operation Result', 'Fail: Key Not Found');
                this.resultsWithStatus.add(resultRow);
                this.failureCount++;
            } else {
                // Prepare for update
                try {
                    Decimal sortingOrderValue = String.isNotBlank(sortingOrder) ? 
                        Decimal.valueOf(sortingOrder) : null;
                    
                    // Create a clone to avoid modifying the queried record directly
                    Product2 productToUpdate = new Product2(
                        Id = product.Id,
                        Product_Key__c = product.Product_Key__c,
                        Sorting_Order__c = sortingOrderValue
                    );
                    
                    // Use Map to automatically deduplicate - last value wins
                    productsToUpdateMap.put(product.Id, productToUpdate);
                    
                    // Track all rows for this product (for handling duplicates in results)
                    if (!rowsByProductId.containsKey(product.Id)) {
                        rowsByProductId.put(product.Id, new List<Map<String, String>>());
                    }
                    rowsByProductId.get(product.Id).add(resultRow);
                } catch (Exception e) {
                    resultRow.put('Operation Result', 'Fail: Invalid Sorting Order value');
                    this.resultsWithStatus.add(resultRow);
                    this.failureCount++;
                }
            }
        }
        
        // Perform bulk update with partial success
        if (!productsToUpdateMap.isEmpty()) {
            List<Product2> productsToUpdate = productsToUpdateMap.values();
            Database.SaveResult[] results = Database.update(productsToUpdate, false);
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                Product2 prod = productsToUpdate[i];
                List<Map<String, String>> affectedRows = rowsByProductId.get(prod.Id);
                
                if (sr.isSuccess()) {
                    // Apply success to all rows with this Product Id
                    for (Map<String, String> resultRow : affectedRows) {
                        resultRow.put('Operation Result', 'Success');
                        this.resultsWithStatus.add(resultRow);
                        this.successCount++;
                    }
                } else {
                    // Apply failure to all rows with this Product Id
                    String errorMsg = 'Fail: ';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + '; ';
                    }
                    String finalErrorMsg = errorMsg.trim();
                    
                    for (Map<String, String> resultRow : affectedRows) {
                        resultRow.put('Operation Result', finalErrorMsg);
                        this.resultsWithStatus.add(resultRow);
                        this.failureCount++;
                    }
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Transfer results to controller for retrieval
        try {
            BulkProductSortingController.updateBatchResults(
                String.valueOf(bc.getJobId()),
                this.resultsWithStatus,
                this.headers,
                this.successCount,
                this.failureCount
            );
            System.debug('Batch completed. Success: ' + this.successCount + ', Failures: ' + this.failureCount);
            System.debug('Results count: ' + this.resultsWithStatus.size());
        } catch (Exception e) {
            System.debug('Error in finish method: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}