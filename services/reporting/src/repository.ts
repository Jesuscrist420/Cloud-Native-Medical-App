import { Storage } from '@google-cloud/storage';

// Domain Model
export interface Report {
  report_id: string;
  type: 'appointment' | 'payment' | 'patient' | 'doctor' | 'custom';
  generated_by: string;
  generated_at: Date;
  format: 'pdf' | 'csv' | 'json';
  file_path: string;
  metadata?: Record<string, any>;
}

// Repository Interface (DIP)
export interface IReportingRepository {
  uploadReport(reportId: string, fileName: string, fileBuffer: Buffer, metadata?: Record<string, any>): Promise<string>;
  downloadReport(reportId: string, fileName: string): Promise<Buffer>;
  listReports(prefix?: string, limit?: number): Promise<string[]>;
  deleteReport(reportId: string, fileName: string): Promise<boolean>;
  generateSignedUrl(reportId: string, fileName: string, expiresInMinutes?: number): Promise<string>;
}

// Cloud Storage Implementation
export class StorageReportingRepository implements IReportingRepository {
  private storage: Storage;
  private bucketName: string;

  constructor(projectId?: string, bucketName?: string) {
    this.storage = new Storage({ projectId });
    this.bucketName = bucketName || `${projectId}-reports`;
  }

  async uploadReport(
    reportId: string, 
    fileName: string, 
    fileBuffer: Buffer, 
    metadata?: Record<string, any>
  ): Promise<string> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${reportId}/${fileName}`);
      
      await blob.save(fileBuffer, {
        metadata: {
          contentType: this.getContentType(fileName),
          metadata: metadata || {},
        },
      });
      
      // Make public for easy access
      await blob.makePublic();
      
      return `https://storage.googleapis.com/${this.bucketName}/${reportId}/${fileName}`;
    } catch (error) {
      console.error('Failed to upload report:', error);
      throw new Error('Storage error while uploading report');
    }
  }

  async downloadReport(reportId: string, fileName: string): Promise<Buffer> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${reportId}/${fileName}`);
      
      const [exists] = await blob.exists();
      if (!exists) {
        throw new Error('Report not found');
      }
      
      const [data] = await blob.download();
      return data;
    } catch (error) {
      console.error('Failed to download report:', error);
      throw new Error('Storage error while downloading report');
    }
  }

  async listReports(prefix: string = '', limit: number = 100): Promise<string[]> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const [files] = await bucket.getFiles({
        prefix,
        maxResults: limit,
      });
      
      return files.map(file => file.name);
    } catch (error) {
      console.error('Failed to list reports:', error);
      throw new Error('Storage error while listing reports');
    }
  }

  async deleteReport(reportId: string, fileName: string): Promise<boolean> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${reportId}/${fileName}`);
      
      const [exists] = await blob.exists();
      if (!exists) {
        return false;
      }
      
      await blob.delete();
      return true;
    } catch (error) {
      console.error('Failed to delete report:', error);
      return false;
    }
  }

  async generateSignedUrl(reportId: string, fileName: string, expiresInMinutes: number = 60): Promise<string> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${reportId}/${fileName}`);
      
      const [exists] = await blob.exists();
      if (!exists) {
        throw new Error('Report not found');
      }
      
      const [url] = await blob.getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: Date.now() + expiresInMinutes * 60 * 1000,
      });
      
      return url;
    } catch (error) {
      console.error('Failed to generate signed URL:', error);
      throw new Error('Storage error while generating signed URL');
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      await bucket.exists();
      return true;
    } catch (error) {
      console.error('Storage health check failed:', error);
      return false;
    }
  }

  // Helper method to determine content type
  private getContentType(fileName: string): string {
    const ext = fileName.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xlsx':
      case 'xls':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}
