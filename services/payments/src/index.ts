import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { EventBus, EventSchemas } from '@app/common';
import { PostgresPaymentRepository } from './repository.js';
import { z } from 'zod';

const PORT = process.env.PORT || 4003;
const TOPIC_PAYMENTS = process.env.TOPIC_PAYMENTS || 'payments';

// Input validation schemas
const CreatePaymentSchema = z.object({
  appointmentId: z.string(),
  amount: z.number().positive(),
  currency: z.string().default('USD'),
  paymentMethod: z.string().optional(),
});

const UpdatePaymentStatusSchema = z.object({
  status: z.enum(['pending', 'completed', 'failed', 'refunded']),
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

  // Initialize repository with database connection
  const repository = new PostgresPaymentRepository({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'payments_db',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
  });

  // Start HTTP server first to pass health checks
  const server = app.listen(PORT, () => console.log(`Payments service on :${PORT}`));

  // Initialize Pub/Sub after server is listening
  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  try {
    await bus.ensureTopic(TOPIC_PAYMENTS);
    console.log(`Pub/Sub topic ${TOPIC_PAYMENTS} ready`);
  } catch (error) {
    console.error('Failed to initialize Pub/Sub:', error);
    // Don't exit - let service run for health checks
  }

  // CREATE payment
  app.post('/payments', async (req, res) => {
    try {
      // 1. Validate input
      const validated = CreatePaymentSchema.parse(req.body);
      const paymentId = `pay_${Date.now()}`;
      
      // 2. Save to database
      const payment = await repository.create({
        payment_id: paymentId,
        appointment_id: validated.appointmentId,
        amount: validated.amount,
        currency: validated.currency,
        status: 'pending',
        payment_method: validated.paymentMethod,
      });
      
      // 3. Publish event
      await bus.publish(TOPIC_PAYMENTS, 'payment.completed', {
        paymentId,
        appointmentId: validated.appointmentId,
        amount: validated.amount,
        currency: validated.currency,
      });
      
      // 4. Return response
      res.status(201).json({ ok: true, payment });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error creating payment:', error);
      res.status(500).json({ ok: false, error: 'Failed to create payment' });
    }
  });

  // GET payment by ID
  app.get('/payments/:id', async (req, res) => {
    try {
      const payment = await repository.findById(req.params.id);
      if (!payment) {
        return res.status(404).json({ ok: false, error: 'Payment not found by Id' });
      }
      res.json({ ok: true, payment });
    } catch (error) {
      console.error('Error fetching payment:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch payment' });
    }
  });

  // GET payments by appointment ID
  app.get('/payments/appointment/:appointmentId', async (req, res) => {
    try {
      const payments = await repository.findByAppointmentId(req.params.appointmentId);
      res.json({ ok: true, payments });
    } catch (error) {
      console.error('Error fetching payments:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch payments by appointment ID' });
    }
  });

  // UPDATE payment status
  app.patch('/payments/:id/status', async (req, res) => {
    try {
      const validated = UpdatePaymentStatusSchema.parse(req.body);
      const payment = await repository.updateStatus(req.params.id, validated.status);
      
      if (!payment) {
        return res.status(404).json({ ok: false, error: 'Payment not found' });
      }

      // Publish event if failed
      if (validated.status === 'failed') {
        await bus.publish(TOPIC_PAYMENTS, 'payment.failed', {
          paymentId: req.params.id,
          appointmentId: payment.appointment_id,
          reason: 'Payment processing failed',
        });
      }
      
      res.json({ ok: true, payment });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error updating payment:', error);
      res.status(500).json({ ok: false, error: 'Failed to update payment' });
    }
  });

  // Health check with database validation
  app.get('/payments/healthz', async (_req, res) => {
    const dbHealthy = await repository.healthCheck();
    if (!dbHealthy) {
      return res.status(503).json({ ok: false, error: 'Database unhealthy' });
    }
    res.json({ ok: true });
  });

  // Graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('SIGTERM received, closing connections...');
    await repository.close();
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
