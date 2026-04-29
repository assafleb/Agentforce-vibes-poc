/**
 * Test class for ProductSortingUpdateBatch
 */
@IsTest
private class ProductSortingUpdateBatchTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test products
        List<Product2> products = new List<Product2>();
        
        for (Integer i = 1; i <= 5; i++) {
            Product2 prod = new Product2(
                Name = 'Test Product ' + i,
                Product_Key__c = 'PROD-00' + i,
                IsActive = true
            );
            products.add(prod);
        }
        
        insert products;
    }
    
    @IsTest
    static void testBatchSuccess() {
        List<Map<String, String>> testRows = new List<Map<String, String>>();
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        
        // Create test data rows
        for (Integer i = 1; i <= 5; i++) {
            Map<String, String> row = new Map<String, String>();
            row.put('Product Key', 'PROD-00' + i);
            row.put('Sorting Order', String.valueOf(i * 10));
            testRows.add(row);
        }
        
        ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(testRows, headers);
        
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify updates
        List<Product2> updatedProducts = [
            SELECT Id, Product_Key__c, Sorting_Order__c 
            FROM Product2 
            WHERE Product_Key__c LIKE 'PROD-%'
            ORDER BY Product_Key__c
        ];
        
        System.assertEquals(5, updatedProducts.size(), 'Should have 5 products');
        System.assertEquals(10, updatedProducts[0].Sorting_Order__c, 'First product should have sorting order 10');
        System.assertEquals(50, updatedProducts[4].Sorting_Order__c, 'Last product should have sorting order 50');
    }
    
    @IsTest
    static void testBatchWithNonExistentKey() {
        List<Map<String, String>> testRows = new List<Map<String, String>>();
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        
        Map<String, String> validRow = new Map<String, String>();
        validRow.put('Product Key', 'PROD-001');
        validRow.put('Sorting Order', '100');
        testRows.add(validRow);
        
        Map<String, String> invalidRow = new Map<String, String>();
        invalidRow.put('Product Key', 'PROD-999');
        invalidRow.put('Sorting Order', '200');
        testRows.add(invalidRow);
        
        ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(testRows, headers);
        
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        System.assertEquals(1, batch.successCount, 'Should have 1 success');
        System.assertEquals(1, batch.failureCount, 'Should have 1 failure');
        
        // Verify the failure has correct message
        Boolean foundFailure = false;
        for (Map<String, String> resultRow : batch.resultsWithStatus) {
            if (resultRow.get('Product Key') == 'PROD-999') {
                System.assertEquals('Fail: Key Not Found', resultRow.get('Operation Result'), 'Should have correct failure message');
                foundFailure = true;
            }
        }
        System.assert(foundFailure, 'Should have found the failed row');
    }
    
    @IsTest
    static void testBatchWithInvalidSortingOrder() {
        List<Map<String, String>> testRows = new List<Map<String, String>>();
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        
        Map<String, String> invalidRow = new Map<String, String>();
        invalidRow.put('Product Key', 'PROD-001');
        invalidRow.put('Sorting Order', 'invalid_number');
        testRows.add(invalidRow);
        
        ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(testRows, headers);
        
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        System.assertEquals(1, batch.failureCount, 'Should have 1 failure');
        
        // Verify the failure has correct message
        System.assert(
            batch.resultsWithStatus[0].get('Operation Result').contains('Invalid Sorting Order'), 
            'Should have correct failure message for invalid number'
        );
    }
    
    @IsTest
    static void testBatchWithEmptyProductKey() {
        List<Map<String, String>> testRows = new List<Map<String, String>>();
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        
        Map<String, String> emptyKeyRow = new Map<String, String>();
        emptyKeyRow.put('Product Key', '');
        emptyKeyRow.put('Sorting Order', '100');
        testRows.add(emptyKeyRow);
        
        ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(testRows, headers);
        
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        System.assertEquals(1, batch.failureCount, 'Should have 1 failure');
        System.assertEquals('Fail: Product Key is empty', batch.resultsWithStatus[0].get('Operation Result'), 
                           'Should have correct failure message for empty key');
    }
    
    @IsTest
    static void testBatchWithNullSortingOrder() {
        List<Map<String, String>> testRows = new List<Map<String, String>>();
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        
        Map<String, String> nullSortingRow = new Map<String, String>();
        nullSortingRow.put('Product Key', 'PROD-001');
        nullSortingRow.put('Sorting Order', '');
        testRows.add(nullSortingRow);
        
        ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(testRows, headers);
        
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Should succeed and set sorting order to null
        System.assertEquals(1, batch.successCount, 'Should have 1 success');
        
        Product2 updatedProduct = [
            SELECT Sorting_Order__c 
            FROM Product2 
            WHERE Product_Key__c = 'PROD-001'
        ];
        
        System.assertEquals(null, updatedProduct.Sorting_Order__c, 'Sorting order should be null');
    }
}