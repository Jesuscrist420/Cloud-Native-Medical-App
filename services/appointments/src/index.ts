import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { EventBus, EventSchemas } from '@app/common';
import { PostgresAppointmentRepository } from './repository.js';
import { z } from 'zod';

const PORT = process.env.PORT || 4002;
const TOPIC_APPOINTMENTS = process.env.TOPIC_APPOINTMENTS || 'appointments';

// Input validation schemas
const CreateAppointmentSchema = z.object({
  appointmentId: z.string(),
  patientId: z.string(),
  doctorId: z.string(),
  datetime: z.string(),
  notes: z.string().optional(),
});

const UpdateStatusSchema = z.object({
  status: z.enum(['pending', 'confirmed', 'completed', 'cancelled']),
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
  const repository = new PostgresAppointmentRepository({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'appointments_db',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
  });

  // Start HTTP server first to pass health checks
  const server = app.listen(PORT, () => console.log(`Appointments service on :${PORT}`));

  // Initialize Pub/Sub after server is listening
  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  try {
    await bus.ensureTopic(TOPIC_APPOINTMENTS);
    console.log(`Pub/Sub topic ${TOPIC_APPOINTMENTS} ready`);
  } catch (error) {
    console.error('Failed to initialize Pub/Sub:', error);
    // Don't exit - let service run for health checks
  }

  // CREATE appointment
  app.post('/appointments', async (req, res) => {
    try {
      // 1. Validate input
      const validated = CreateAppointmentSchema.parse(req.body);
      
      // 2. Save to database
      const appointment = await repository.create({
        appointment_id: validated.appointmentId,
        patient_id: validated.patientId,
        doctor_id: validated.doctorId,
        appointment_date: validated.datetime,
        status: 'pending',
        notes: validated.notes,
      });
      
      // 3. Publish event
      await bus.publish(TOPIC_APPOINTMENTS, 'appointment.created', {
        appointmentId: validated.appointmentId,
        patientId: validated.patientId,
        doctorId: validated.doctorId,
        datetime: validated.datetime,
      });
      
      // 4. Return response
      res.status(201).json({ ok: true, appointment });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error creating appointment:', error);
      res.status(500).json({ ok: false, error: 'Failed to create appointment' });
    }
  });

  // GET appointment by ID
  app.get('/appointments/:id', async (req, res) => {
    try {
      const appointment = await repository.findById(req.params.id);
      if (!appointment) {
        return res.status(404).json({ ok: false, error: 'Appointment not found by Id' });
      }
      res.json({ ok: true, appointment });
    } catch (error) {
      console.error('Error fetching appointment by Id:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch appointment by Id' });
    }
  });

  // GET appointments by patient ID
  app.get('/appointments/patient/:patientId', async (req, res) => {
    try {
      const appointments = await repository.findByPatientId(req.params.patientId);
      res.json({ ok: true, appointments });
    } catch (error) {
      console.error('Error fetching appointments by patient ID:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch appointments by patient ID' });
    }
  });

  // GET appointments by doctor ID
  app.get('/appointments/doctor/:doctorId', async (req, res) => {
    try {
      const appointments = await repository.findByDoctorId(req.params.doctorId);
      res.json({ ok: true, appointments });
    } catch (error) {
      console.error('Error fetching appointments by doctor ID:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch appointments by doctor ID' });
    }
  });

  // UPDATE appointment status
  app.patch('/appointments/:id/status', async (req, res) => {
    try {
      const validated = UpdateStatusSchema.parse(req.body);
      const appointment = await repository.updateStatus(req.params.id, validated.status);
      
      if (!appointment) {
        return res.status(404).json({ ok: false, error: 'Appointment not found' });
      }

      // Publish event if cancelled
      if (validated.status === 'cancelled') {
        await bus.publish(TOPIC_APPOINTMENTS, 'appointment.cancelled', {
          appointmentId: req.params.id,
        });
      }
      
      res.json({ ok: true, appointment });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error updating appointment:', error);
      res.status(500).json({ ok: false, error: 'Failed to update appointment' });
    }
  });

  // DELETE appointment
  app.delete('/appointments/:id', async (req, res) => {
    try {
      const deleted = await repository.delete(req.params.id);
      if (!deleted) {
        return res.status(404).json({ ok: false, error: 'Appointment not found' });
      }
      res.json({ ok: true, message: 'Appointment deleted' });
    } catch (error) {
      console.error('Error deleting appointment:', error);
      res.status(500).json({ ok: false, error: 'Failed to delete appointment' });
    }
  });

  // Health check with database validation
  app.get('/appointments/healthz', async (_req, res) => {
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
