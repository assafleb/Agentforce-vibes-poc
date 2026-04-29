/**
 * Controller for Bulk Product Sorting Order Update LWC
 */
public with sharing class BulkProductSortingController {
    
    private static final String CONTENT_VERSION_TITLE_PREFIX = 'BatchResults_';
    
    public class BatchJobResult {
        @AuraEnabled public List<Map<String, String>> results { get; set; }
        @AuraEnabled public List<String> headers { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer failureCount { get; set; }
        @AuraEnabled public Integer totalCount { get; set; }
        @AuraEnabled public String status { get; set; }
        
        public BatchJobResult() {
            this.results = new List<Map<String, String>>();
            this.headers = new List<String>();
            this.successCount = 0;
            this.failureCount = 0;
            this.totalCount = 0;
            this.status = 'Processing';
        }
    }
    
    /**
     * Process uploaded file and initiate batch job
     */
    @AuraEnabled
    public static String processFile(String fileContent, String fileName) {
        try {
            // Validate file type
            if (!fileName.toLowerCase().endsWith('.csv')) {
                throw new AuraHandledException('Only CSV files are supported');
            }
            
            // Parse CSV content
            FileParserUtility.ParsedData parsedData = FileParserUtility.parseCSV(fileContent);
            
            if (parsedData.rows.isEmpty()) {
                throw new AuraHandledException('No data rows found in file');
            }
            
            // Initiate batch processing
            ProductSortingUpdateBatch batch = new ProductSortingUpdateBatch(
                parsedData.rows, 
                parsedData.headers
            );
            
            Id batchJobId = Database.executeBatch(batch, 200);
            
            return batchJobId;
            
        } catch (FileParserUtility.FileParserException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error processing file: ' + e.getMessage());
        }
    }
    
    /**
     * Check batch job status
     */
    @AuraEnabled
    public static Map<String, Object> checkBatchStatus(String batchJobId) {
        try {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
                       CompletedDate, CreatedDate
                FROM AsyncApexJob
                WHERE Id = :batchJobId
                LIMIT 1
            ];
            
            Map<String, Object> statusInfo = new Map<String, Object>();
            statusInfo.put('status', job.Status);
            statusInfo.put('jobItemsProcessed', job.JobItemsProcessed);
            statusInfo.put('totalJobItems', job.TotalJobItems);
            statusInfo.put('numberOfErrors', job.NumberOfErrors);
            
            // Calculate progress percentage
            if (job.TotalJobItems > 0) {
                Decimal progress = (Decimal.valueOf(job.JobItemsProcessed) / 
                                   Decimal.valueOf(job.TotalJobItems)) * 100;
                statusInfo.put('progress', progress.intValue());
            } else {
                statusInfo.put('progress', 0);
            }
            
            // Check if completed
            if (job.Status == 'Completed' || job.Status == 'Failed' || job.Status == 'Aborted') {
                statusInfo.put('isComplete', true);
            } else {
                statusInfo.put('isComplete', false);
            }
            
            return statusInfo;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error checking batch status: ' + e.getMessage());
        }
    }
    
    /**
     * Get batch results after completion
     * Retrieves results from ContentVersion storage
     */
    @AuraEnabled
    public static BatchJobResult getBatchResults(String batchJobId) {
        try {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
                FROM AsyncApexJob
                WHERE Id = :batchJobId
                LIMIT 1
            ];
            
            // Try to retrieve results from ContentVersion
            try {
                List<ContentVersion> cvList = [
                    SELECT Id, VersionData, Title
                    FROM ContentVersion
                    WHERE Title = :CONTENT_VERSION_TITLE_PREFIX + batchJobId
                    AND IsLatest = true
                    LIMIT 1
                ];
                
                if (!cvList.isEmpty()) {
                    String jsonResults = cvList[0].VersionData.toString();
                    BatchJobResult result = (BatchJobResult)JSON.deserialize(jsonResults, BatchJobResult.class);
                    result.status = job.Status;
                    return result;
                }
            } catch (Exception e) {
                System.debug('Error retrieving stored results: ' + e.getMessage());
            }
            
            // Fallback: return summary from job info
            BatchJobResult result = new BatchJobResult();
            result.status = job.Status;
            result.totalCount = job.TotalJobItems;
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving batch results: ' + e.getMessage());
        }
    }
    
    /**
     * Generate results CSV file for download
     */
    @AuraEnabled
    public static String generateResultsFile(String batchJobId) {
        try {
            BatchJobResult result = getBatchResults(batchJobId);
            
            // Generate CSV with Operation Result column
            String csvContent = FileParserUtility.generateResultsCSV(
                result.results, 
                result.headers
            );
            
            return csvContent;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generating results file: ' + e.getMessage());
        }
    }
    
    /**
     * Update batch results (called from batch finish method)
     * Stores results as ContentVersion for persistent storage
     */
    @AuraEnabled
    public static void updateBatchResults(String batchJobId, List<Map<String, String>> results, 
                                         List<String> headers, Integer successCount, Integer failureCount) {
        try {
            // Create a wrapper object for the results
            BatchJobResult resultWrapper = new BatchJobResult();
            resultWrapper.results = results;
            resultWrapper.headers = headers;
            resultWrapper.successCount = successCount;
            resultWrapper.failureCount = failureCount;
            resultWrapper.totalCount = results.size();
            resultWrapper.status = 'Completed';
            
            // Serialize to JSON
            String jsonResults = JSON.serialize(resultWrapper);
            Blob jsonBlob = Blob.valueOf(jsonResults);
            
            // Store as ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = CONTENT_VERSION_TITLE_PREFIX + batchJobId;
            cv.PathOnClient = 'results.json';
            cv.VersionData = jsonBlob;
            cv.IsMajorVersion = true;
            cv.Description = 'Batch job results for ' + batchJobId;
            
            insert cv;
            
            System.debug('Batch results stored successfully for job: ' + batchJobId);
        } catch (Exception e) {
            System.debug('Error updating batch results: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}