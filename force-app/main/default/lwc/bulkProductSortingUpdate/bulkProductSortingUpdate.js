import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processFile from '@salesforce/apex/BulkProductSortingController.processFile';
import checkBatchStatus from '@salesforce/apex/BulkProductSortingController.checkBatchStatus';
import getBatchResults from '@salesforce/apex/BulkProductSortingController.getBatchResults';
import generateResultsFile from '@salesforce/apex/BulkProductSortingController.generateResultsFile';

export default class BulkProductSortingUpdate extends LightningElement {
    @track fileName = '';
    @track fileContent = '';
    @track isFileLoaded = false;
    @track isProcessing = false;
    @track batchJobId = '';
    @track progressValue = 0;
    @track statusMessage = '';
    @track showResults = false;
    @track successCount = 0;
    @track failureCount = 0;
    @track totalCount = 0;
    @track resultsFileContent = '';
    @track activityLog = [];
    @track detailedResults = [];
    
    statusCheckInterval;

    get acceptedFormats() {
        return '.csv';
    }

    get showProgressBar() {
        return this.isProcessing && this.batchJobId;
    }

    get isApplyDisabled() {
        return !this.isFileLoaded || this.isProcessing;
    }

    get showDownloadButton() {
        return this.showResults;
    }

    get activityLogText() {
        return this.activityLog.map(entry => entry.message).join('\n');
    }

    get hasActivityLog() {
        return this.activityLog.length > 0;
    }

    handleFileUpload(event) {
        const uploadedFiles = event.target.files;
        
        if (uploadedFiles.length > 0) {
            const file = uploadedFiles[0];
            this.fileName = file.name;
            
            // Validate file extension
            if (!file.name.toLowerCase().endsWith('.csv')) {
                this.showToast('Error', 'Only CSV files are supported', 'error');
                this.resetFileUpload();
                return;
            }

            const reader = new FileReader();
            
            reader.onload = () => {
                this.fileContent = reader.result;
                this.isFileLoaded = true;
                this.addToActivityLog(`✓ File uploaded: ${this.fileName}`);
                this.showToast('Success', `File "${this.fileName}" loaded successfully`, 'success');
            };
            
            reader.onerror = () => {
                this.addToActivityLog(`✗ Failed to read file: ${this.fileName}`);
                this.showToast('Error', 'Failed to read file', 'error');
                this.resetFileUpload();
            };
            
            reader.readAsText(file);
        }
    }

    handleApply() {
        if (!this.fileContent) {
            this.showToast('Error', 'Please upload a file first', 'error');
            return;
        }

        this.isProcessing = true;
        this.showResults = false;
        this.statusMessage = 'Processing file...';
        this.progressValue = 0;
        
        // Clear previous activity log and results
        this.activityLog = [];
        this.detailedResults = [];
        this.successCount = 0;
        this.failureCount = 0;
        this.totalCount = 0;
        
        this.addToActivityLog('⏳ Starting batch processing...');

        processFile({ 
            fileContent: this.fileContent, 
            fileName: this.fileName 
        })
        .then(result => {
            this.batchJobId = result;
            this.statusMessage = 'Batch job started. Processing records...';
            this.addToActivityLog(`✓ Batch job started (ID: ${result.substring(0, 15)}...)`);
            this.startStatusCheck();
        })
        .catch(error => {
            this.addToActivityLog(`✗ Failed to start batch job: ${error.body.message}`);
            this.handleError(error);
            this.isProcessing = false;
        });
    }

    startStatusCheck() {
        // Check status every 2 seconds
        this.statusCheckInterval = setInterval(() => {
            this.checkJobStatus();
        }, 2000);
    }

    checkJobStatus() {
        if (!this.batchJobId) {
            return;
        }

        checkBatchStatus({ batchJobId: this.batchJobId })
        .then(result => {
            this.progressValue = result.progress || 0;
            const prevMessage = this.statusMessage;
            this.statusMessage = `Processing: ${result.jobItemsProcessed} of ${result.totalJobItems} batches completed`;
            
            // Only log if status changed
            if (prevMessage !== this.statusMessage && result.jobItemsProcessed > 0) {
                this.addToActivityLog(`⏳ Processing batch ${result.jobItemsProcessed} of ${result.totalJobItems}...`);
            }
            
            if (result.isComplete) {
                this.handleJobComplete(result);
            }
        })
        .catch(error => {
            this.addToActivityLog(`✗ Error checking batch status`);
            this.handleError(error);
            this.stopStatusCheck();
        });
    }

    handleJobComplete(jobStatus) {
        this.stopStatusCheck();
        this.isProcessing = false;
        this.progressValue = 100;
        
        if (jobStatus.status === 'Completed') {
            this.statusMessage = 'Processing completed successfully';
            this.addToActivityLog('✓ Batch processing complete');
            this.loadDetailedResults();
        } else if (jobStatus.status === 'Failed') {
            this.statusMessage = 'Batch job failed';
            this.addToActivityLog('✗ Batch job failed');
            this.showToast('Error', 'Batch processing failed', 'error');
        } else if (jobStatus.status === 'Aborted') {
            this.statusMessage = 'Batch job was aborted';
            this.addToActivityLog('✗ Batch job was aborted');
            this.showToast('Warning', 'Batch processing was aborted', 'warning');
        }
    }

    loadDetailedResults() {
        getBatchResults({ batchJobId: this.batchJobId })
        .then(batchResult => {
            this.successCount = batchResult.successCount || 0;
            this.failureCount = batchResult.failureCount || 0;
            this.totalCount = batchResult.totalCount || 0;
            this.detailedResults = batchResult.results || [];
            
            // Add detailed results to activity log
            this.addToActivityLog('');
            this.addToActivityLog('─────── Results ───────');
            
            if (this.detailedResults && this.detailedResults.length > 0) {
                this.detailedResults.forEach(row => {
                    const productKey = row['Product Key'] || 'Unknown';
                    const sortingOrder = row['Sorting Order'] || 'N/A';
                    const result = row['Operation Result'] || 'Unknown';
                    
                    const icon = result.startsWith('Success') ? '✓' : '✗';
                    const status = result.startsWith('Success') ? 'Success' : result;
                    
                    this.addToActivityLog(`${icon} Product ${productKey} → Sorting Order: ${sortingOrder} [${status}]`);
                });
            }
            
            this.addToActivityLog('─────────────────────');
            this.addToActivityLog(`Summary: ${this.successCount} successful, ${this.failureCount} failed`);
            
            this.showResults = true;
            this.showToast(
                'Complete', 
                `Processing completed: ${this.successCount} successful, ${this.failureCount} failed`, 
                'success'
            );
        })
        .catch(error => {
            this.addToActivityLog('✗ Failed to load detailed results');
            this.handleError(error);
        });
    }

    handleDownloadResults() {
        generateResultsFile({ batchJobId: this.batchJobId })
        .then(csvContent => {
            if (!csvContent) {
                this.showToast('Error', 'No results available to download', 'error');
                return;
            }

            // Create download link
            const blob = new Blob([csvContent], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `results_${this.fileName}`;
            link.click();
            window.URL.revokeObjectURL(url);
            
            this.addToActivityLog('✓ Results CSV downloaded');
            this.showToast('Success', 'Results file downloaded', 'success');
        })
        .catch(error => {
            this.addToActivityLog('✗ Failed to download results');
            this.handleError(error);
        });
    }

    handleCopyToClipboard() {
        const logText = this.activityLogText;
        
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(logText)
                .then(() => {
                    this.showToast('Success', 'Activity log copied to clipboard', 'success');
                })
                .catch(() => {
                    this.fallbackCopyToClipboard(logText);
                });
        } else {
            this.fallbackCopyToClipboard(logText);
        }
    }

    handleClearLog() {
        this.activityLog = [];
        this.detailedResults = [];
        this.showResults = false;
        this.showToast('Success', 'Activity log cleared', 'success');
    }

    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        document.body.appendChild(textArea);
        textArea.select();
        
        try {
            document.execCommand('copy');
            this.showToast('Success', 'Activity log copied to clipboard', 'success');
        } catch (err) {
            this.showToast('Error', 'Failed to copy to clipboard', 'error');
        }
        
        document.body.removeChild(textArea);
    }

    addToActivityLog(message) {
        const logEntry = {
            id: Date.now() + Math.random(), // Unique ID for each entry
            message: message
        };
        this.activityLog = [...this.activityLog, logEntry];
    }

    handleReset() {
        this.resetFileUpload();
        this.isProcessing = false;
        this.batchJobId = '';
        this.progressValue = 0;
        this.statusMessage = '';
        this.showResults = false;
        this.successCount = 0;
        this.failureCount = 0;
        this.totalCount = 0;
        this.resultsFileContent = '';
        this.activityLog = [];
        this.detailedResults = [];
        this.stopStatusCheck();
    }

    resetFileUpload() {
        this.fileName = '';
        this.fileContent = '';
        this.isFileLoaded = false;
        
        // Reset file input
        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    stopStatusCheck() {
        if (this.statusCheckInterval) {
            clearInterval(this.statusCheckInterval);
            this.statusCheckInterval = null;
        }
    }

    handleError(error) {
        let errorMessage = 'Unknown error';
        
        if (error.body) {
            if (error.body.message) {
                errorMessage = error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                errorMessage = error.body.pageErrors[0].message;
            }
        } else if (error.message) {
            errorMessage = error.message;
        }
        
        this.showToast('Error', errorMessage, 'error');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    disconnectedCallback() {
        this.stopStatusCheck();
    }
}
