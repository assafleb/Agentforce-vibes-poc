/**
 * Utility class for parsing CSV files
 */
public with sharing class FileParserUtility {
    
    public class ParsedData {
        public List<String> headers { get; set; }
        public List<Map<String, String>> rows { get; set; }
        
        public ParsedData() {
            this.headers = new List<String>();
            this.rows = new List<Map<String, String>>();
        }
    }
    
    /**
     * Parse CSV content into structured data
     */
    public static ParsedData parseCSV(String csvContent) {
        ParsedData result = new ParsedData();
        
        if (String.isBlank(csvContent)) {
            throw new FileParserException('File content is empty');
        }
        
        List<String> lines = csvContent.split('\n');
        
        if (lines.isEmpty()) {
            throw new FileParserException('No data found in file');
        }
        
        // Parse headers
        String headerLine = lines[0].trim();
        result.headers = parseCSVLine(headerLine);
        
        // Validate required columns
        if (!result.headers.contains('Product Key')) {
            throw new FileParserException('Missing required column: Product Key');
        }
        
        if (!result.headers.contains('Sorting Order')) {
            throw new FileParserException('Missing required column: Sorting Order');
        }
        
        // Parse data rows
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();
            
            if (String.isNotBlank(line)) {
                List<String> values = parseCSVLine(line);
                
                if (values.size() == result.headers.size()) {
                    Map<String, String> rowData = new Map<String, String>();
                    
                    for (Integer j = 0; j < result.headers.size(); j++) {
                        rowData.put(result.headers[j], values[j]);
                    }
                    
                    result.rows.add(rowData);
                }
            }
        }
        
        return result;
    }
    
    /**
     * Parse a single CSV line handling quoted values
     */
    private static List<String> parseCSVLine(String line) {
        List<String> values = new List<String>();
        String currentValue = '';
        Boolean inQuotes = false;
        
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            
            if (ch == '"') {
                inQuotes = !inQuotes;
            } else if (ch == ',' && !inQuotes) {
                values.add(currentValue.trim());
                currentValue = '';
            } else {
                currentValue += ch;
            }
        }
        
        // Add the last value
        values.add(currentValue.trim());
        
        return values;
    }
    
    /**
     * Generate CSV content with results
     */
    public static String generateResultsCSV(List<Map<String, String>> rows, List<String> headers) {
        List<String> lines = new List<String>();
        
        // Add headers with Operation Result column
        List<String> resultHeaders = new List<String>(headers);
        if (!resultHeaders.contains('Operation Result')) {
            resultHeaders.add('Operation Result');
        }
        lines.add(String.join(resultHeaders, ','));
        
        // Add data rows
        for (Map<String, String> row : rows) {
            List<String> values = new List<String>();
            
            for (String header : resultHeaders) {
                String value = row.get(header);
                
                // Handle values with commas or quotes
                if (value != null && (value.contains(',') || value.contains('"'))) {
                    value = '"' + value.replace('"', '""') + '"';
                }
                
                values.add(value != null ? value : '');
            }
            
            lines.add(String.join(values, ','));
        }
        
        return String.join(lines, '\n');
    }
    
    public class FileParserException extends Exception {}
}