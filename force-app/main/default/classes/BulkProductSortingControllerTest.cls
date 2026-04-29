/**
 * Test class for BulkProductSortingController
 */
@IsTest
private class BulkProductSortingControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test products
        List<Product2> products = new List<Product2>();
        
        for (Integer i = 1; i <= 3; i++) {
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
    static void testProcessFile_Success() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100\nPROD-002,200\nPROD-003,300';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
        Test.stopTest();
        
        System.assertNotEquals(null, batchJobId, 'Should return batch job ID');
        
        // Verify batch job was created
        List<AsyncApexJob> jobs = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchJobId];
        System.assertEquals(1, jobs.size(), 'Batch job should exist');
    }
    
    @IsTest
    static void testProcessFile_InvalidFileType() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100';
        String fileName = 'test_products.xlsx';
        
        Test.startTest();
        try {
            String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
            System.assert(false, 'Should have thrown exception for non-CSV file');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('CSV'), 'Error should mention CSV file type');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testProcessFile_MissingColumns() {
        String csvContent = 'Product Key\nPROD-001\nPROD-002';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        try {
            String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
            System.assert(false, 'Should have thrown exception for missing column');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Sorting Order'), 'Error should mention missing column');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testProcessFile_EmptyFile() {
        String csvContent = 'Product Key,Sorting Order\n';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        try {
            String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
            System.assert(false, 'Should have thrown exception for empty data');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No data'), 'Error should mention no data');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testCheckBatchStatus() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
        
        Map<String, Object> statusInfo = BulkProductSortingController.checkBatchStatus(batchJobId);
        Test.stopTest();
        
        System.assertNotEquals(null, statusInfo, 'Should return status info');
        System.assert(statusInfo.containsKey('status'), 'Should contain status');
        System.assert(statusInfo.containsKey('progress'), 'Should contain progress');
        System.assert(statusInfo.containsKey('isComplete'), 'Should contain isComplete flag');
    }
    
    @IsTest
    static void testGetBatchResults() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
        
        BulkProductSortingController.BatchJobResult result = 
            BulkProductSortingController.getBatchResults(batchJobId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return batch results');
        System.assertNotEquals(null, result.status, 'Should have status');
    }
    
    @IsTest
    static void testGenerateResultsFile() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
        
        // In test context, batch completes immediately
        String resultsCSV = BulkProductSortingController.generateResultsFile(batchJobId);
        Test.stopTest();
        
        System.assertNotEquals(null, resultsCSV, 'Should return results CSV');
    }
    
    @IsTest
    static void testUpdateBatchResults() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100';
        String fileName = 'test_products.csv';
        
        Test.startTest();
        String batchJobId = BulkProductSortingController.processFile(csvContent, fileName);
        
        List<Map<String, String>> results = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put('Product Key', 'PROD-001');
        row.put('Sorting Order', '100');
        row.put('Operation Result', 'Success');
        results.add(row);
        
        BulkProductSortingController.updateBatchResults(batchJobId, results, 1, 0);
        Test.stopTest();
        
        // Verify results were stored
        BulkProductSortingController.BatchJobResult result = 
            BulkProductSortingController.getBatchResults(batchJobId);
        
        System.assertEquals(1, result.successCount, 'Should have 1 success');
        System.assertEquals(0, result.failureCount, 'Should have 0 failures');
    }
}
