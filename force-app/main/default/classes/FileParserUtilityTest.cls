/**
 * Test class for FileParserUtility
 */
@IsTest
private class FileParserUtilityTest {
    
    @IsTest
    static void testParseCSV_ValidFile() {
        String csvContent = 'Product Key,Sorting Order\nPROD-001,100\nPROD-002,200';
        
        Test.startTest();
        FileParserUtility.ParsedData result = FileParserUtility.parseCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(2, result.headers.size(), 'Should have 2 headers');
        System.assertEquals('Product Key', result.headers[0], 'First header should be Product Key');
        System.assertEquals('Sorting Order', result.headers[1], 'Second header should be Sorting Order');
        System.assertEquals(2, result.rows.size(), 'Should have 2 data rows');
        System.assertEquals('PROD-001', result.rows[0].get('Product Key'), 'First row Product Key should match');
        System.assertEquals('100', result.rows[0].get('Sorting Order'), 'First row Sorting Order should match');
    }
    
    @IsTest
    static void testParseCSV_MissingProductKeyColumn() {
        String csvContent = 'Sorting Order\n100\n200';
        
        Test.startTest();
        try {
            FileParserUtility.ParsedData result = FileParserUtility.parseCSV(csvContent);
            System.assert(false, 'Should have thrown exception');
        } catch (FileParserUtility.FileParserException e) {
            System.assert(e.getMessage().contains('Product Key'), 'Error should mention Product Key');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testParseCSV_MissingSortingOrderColumn() {
        String csvContent = 'Product Key\nPROD-001\nPROD-002';
        
        Test.startTest();
        try {
            FileParserUtility.ParsedData result = FileParserUtility.parseCSV(csvContent);
            System.assert(false, 'Should have thrown exception');
        } catch (FileParserUtility.FileParserException e) {
            System.assert(e.getMessage().contains('Sorting Order'), 'Error should mention Sorting Order');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testParseCSV_EmptyContent() {
        String csvContent = '';
        
        Test.startTest();
        try {
            FileParserUtility.ParsedData result = FileParserUtility.parseCSV(csvContent);
            System.assert(false, 'Should have thrown exception');
        } catch (FileParserUtility.FileParserException e) {
            System.assert(e.getMessage().contains('empty'), 'Error should mention empty content');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testParseCSV_QuotedValues() {
        String csvContent = 'Product Key,Sorting Order,Description\n"PROD-001",100,"Test, Product"\nPROD-002,200,Normal';
        
        Test.startTest();
        FileParserUtility.ParsedData result = FileParserUtility.parseCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(2, result.rows.size(), 'Should have 2 data rows');
        System.assertEquals('PROD-001', result.rows[0].get('Product Key'), 'Should handle quoted Product Key');
        System.assertEquals('Test, Product', result.rows[0].get('Description'), 'Should handle quoted values with commas');
    }
    
    @IsTest
    static void testGenerateResultsCSV() {
        List<String> headers = new List<String>{'Product Key', 'Sorting Order'};
        List<Map<String, String>> rows = new List<Map<String, String>>();
        
        Map<String, String> row1 = new Map<String, String>();
        row1.put('Product Key', 'PROD-001');
        row1.put('Sorting Order', '100');
        row1.put('Operation Result', 'Success');
        rows.add(row1);
        
        Map<String, String> row2 = new Map<String, String>();
        row2.put('Product Key', 'PROD-002');
        row2.put('Sorting Order', '200');
        row2.put('Operation Result', 'Fail: Key Not Found');
        rows.add(row2);
        
        Test.startTest();
        String csvContent = FileParserUtility.generateResultsCSV(rows, headers);
        Test.stopTest();
        
        System.assert(csvContent.contains('Product Key'), 'Should contain Product Key header');
        System.assert(csvContent.contains('Operation Result'), 'Should contain Operation Result header');
        System.assert(csvContent.contains('PROD-001'), 'Should contain first product key');
        System.assert(csvContent.contains('Success'), 'Should contain success status');
        System.assert(csvContent.contains('Fail: Key Not Found'), 'Should contain failure message');
    }
    
    @IsTest
    static void testGenerateResultsCSV_WithCommasAndQuotes() {
        List<String> headers = new List<String>{'Product Key', 'Description'};
        List<Map<String, String>> rows = new List<Map<String, String>>();
        
        Map<String, String> row1 = new Map<String, String>();
        row1.put('Product Key', 'PROD-001');
        row1.put('Description', 'Test, Product "Special"');
        row1.put('Operation Result', 'Success');
        rows.add(row1);
        
        Test.startTest();
        String csvContent = FileParserUtility.generateResultsCSV(rows, headers);
        Test.stopTest();
        
        System.assert(csvContent.contains('"'), 'Should quote values with commas or quotes');
    }
}