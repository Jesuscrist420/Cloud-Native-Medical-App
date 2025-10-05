import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { StorageReportingRepository } from './repository.js';
import { z } from 'zod';

const PORT = process.env.PORT || 4007;

// Input validation schemas
const GenerateReportSchema = z.object({
  reportId: z.string(),
  type: z.enum(['appointment', 'payment', 'patient', 'doctor', 'custom']),
  format: z.enum(['pdf', 'csv', 'json']),
  data: z.record(z.any()),
});

async function main() {
  const app = express();
  
  // CORS configuration - Allow requests from frontend
  app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
  }));
  
  app.use(express.json());

  // Initialize repository
  const repository = new StorageReportingRepository(
    process.env.GOOGLE_CLOUD_PROJECT,
    process.env.REPORTS_BUCKET
  );

  // GENERATE/UPLOAD report
  app.post('/reports', async (req, res) => {
    try {
      // 1. Validate input
      const validated = GenerateReportSchema.parse(req.body);
      
      // 2. Generate report content (simplified - in real app would use PDF/CSV library)
      const reportContent = JSON.stringify(validated.data, null, 2);
      const fileName = `report_${Date.now()}.${validated.format}`;
      
      // 3. Upload to Cloud Storage
      const url = await repository.uploadReport(
        validated.reportId,
        fileName,
        Buffer.from(reportContent),
        {
          type: validated.type,
          format: validated.format,
          generated_at: new Date().toISOString(),
        }
      );
      
      res.status(201).json({
        ok: true,
        report: {
          reportId: validated.reportId,
          fileName,
          url,
          type: validated.type,
          format: validated.format,
        },
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error generating report:', error);
      res.status(500).json({ ok: false, error: 'Failed to generate report' });
    }
  });

  // GET report (download)
  app.get('/reports/:reportId/:fileName', async (req, res) => {
    try {
      const { reportId, fileName } = req.params;
      const buffer = await repository.downloadReport(reportId, fileName);
      
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.send(buffer);
    } catch (error: any) {
      if (error.message === 'Report not found') {
        return res.status(404).json({ ok: false, error: 'Report not found' });
      }
      console.error('Error downloading report:', error);
      res.status(500).json({ ok: false, error: 'Failed to download report' });
    }
  });

  // GET signed URL for report
  app.get('/reports/:reportId/:fileName/url', async (req, res) => {
    try {
      const { reportId, fileName } = req.params;
      const expiresIn = req.query.expiresIn ? parseInt(req.query.expiresIn as string) : 60;
      
      const url = await repository.generateSignedUrl(reportId, fileName, expiresIn);
      
      res.json({ ok: true, url, expiresIn });
    } catch (error: any) {
      if (error.message === 'Report not found') {
        return res.status(404).json({ ok: false, error: 'Report not found' });
      }
      console.error('Error generating signed URL:', error);
      res.status(500).json({ ok: false, error: 'Failed to generate signed URL' });
    }
  });

  // LIST reports
  app.get('/reports', async (req, res) => {
    try {
      const prefix = (req.query.prefix as string) || '';
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 100;
      
      const files = await repository.listReports(prefix, limit);
      
      res.json({ ok: true, reports: files });
    } catch (error) {
      console.error('Error listing reports:', error);
      res.status(500).json({ ok: false, error: 'Failed to list reports' });
    }
  });

  // DELETE report
  app.delete('/reports/:reportId/:fileName', async (req, res) => {
    try {
      const { reportId, fileName } = req.params;
      const deleted = await repository.deleteReport(reportId, fileName);
      
      if (!deleted) {
        return res.status(404).json({ ok: false, error: 'Report not found' });
      }
      
      res.json({ ok: true, message: 'Report deleted' });
    } catch (error) {
      console.error('Error deleting report:', error);
      res.status(500).json({ ok: false, error: 'Failed to delete report' });
    }
  });

  // Health check
  app.get('/reports/healthz', async (_req, res) => {
    const storageHealthy = await repository.healthCheck();
    if (!storageHealthy) {
      return res.status(503).json({ ok: false, error: 'Storage unhealthy' });
    }
    res.json({ ok: true });
  });

  app.listen(PORT, () => console.log(`Reporting service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
