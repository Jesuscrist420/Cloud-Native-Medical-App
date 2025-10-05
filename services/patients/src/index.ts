import 'dotenv/config';
import express from 'express';
import { FirestorePatientRepository } from './repository.js';
import { z } from 'zod';

const PORT = process.env.PORT || 4005;

// Input validation schemas
const CreatePatientSchema = z.object({
  patientId: z.string(),
  name: z.string(),
  email: z.string().email(),
  phone: z.string().optional(),
  dateOfBirth: z.string().optional(),
  address: z.string().optional(),
  medicalHistory: z.string().optional(),
});

const UpdatePatientSchema = z.object({
  name: z.string().optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  medicalHistory: z.string().optional(),
});

async function main() {
  const app = express();
  app.use(express.json());

  // Initialize repository
  const repository = new FirestorePatientRepository(
    process.env.GOOGLE_CLOUD_PROJECT,
    process.env.PATIENTS_BUCKET
  );

  // CREATE patient
  app.post('/patients', async (req, res) => {
    try {
      // 1. Validate input
      const validated = CreatePatientSchema.parse(req.body);
      
      // 2. Check if patient already exists
      const existingPatient = await repository.findByEmail(validated.email);
      if (existingPatient) {
        return res.status(409).json({ ok: false, error: 'Patient with this email already exists' });
      }
      
      // 3. Create patient
      const patient = await repository.create({
        patient_id: validated.patientId,
        name: validated.name,
        email: validated.email,
        phone: validated.phone,
        date_of_birth: validated.dateOfBirth,
        address: validated.address,
        medical_history: validated.medicalHistory,
      });
      
      res.status(201).json({ ok: true, patient });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error creating patient:', error);
      res.status(500).json({ ok: false, error: 'Failed to create patient' });
    }
  });

  // GET patient by ID
  app.get('/patients/:id', async (req, res) => {
    try {
      const patient = await repository.findById(req.params.id);
      if (!patient) {
        return res.status(404).json({ ok: false, error: 'Patient not found by Id' });
      }
      res.json({ ok: true, patient });
    } catch (error) {
      console.error('Error fetching patient:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch patient' });
    }
  });

  // GET patient by email
  app.get('/patients/email/:email', async (req, res) => {
    try {
      const patient = await repository.findByEmail(req.params.email);
      if (!patient) {
        return res.status(404).json({ ok: false, error: 'Patient not found by email' });
      }
      res.json({ ok: true, patient });
    } catch (error) {
      console.error('Error fetching patient:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch patient' });
    }
  });

  // LIST patients
  app.get('/patients', async (req, res) => {
    try {
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 50;
      const patients = await repository.list(limit);
      res.json({ ok: true, patients });
    } catch (error) {
      console.error('Error listing patients:', error);
      res.status(500).json({ ok: false, error: 'Failed to list patients' });
    }
  });

  // UPDATE patient
  app.patch('/patients/:id', async (req, res) => {
    try {
      const validated = UpdatePatientSchema.parse(req.body);
      const patient = await repository.update(req.params.id, validated);
      
      if (!patient) {
        return res.status(404).json({ ok: false, error: 'Patient not found' });
      }
      
      res.json({ ok: true, patient });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error updating patient:', error);
      res.status(500).json({ ok: false, error: 'Failed to update patient' });
    }
  });

  // DELETE patient
  app.delete('/patients/:id', async (req, res) => {
    try {
      const deleted = await repository.delete(req.params.id);
      if (!deleted) {
        return res.status(404).json({ ok: false, error: 'Patient not found' });
      }
      res.json({ ok: true, message: 'Patient deleted' });
    } catch (error) {
      console.error('Error deleting patient:', error);
      res.status(500).json({ ok: false, error: 'Failed to delete patient' });
    }
  });

  // Health check
  app.get('/healthz', async (_req, res) => {
    const dbHealthy = await repository.healthCheck();
    if (!dbHealthy) {
      return res.status(503).json({ ok: false, error: 'Database unhealthy' });
    }
    res.json({ ok: true });
  });

  app.listen(PORT, () => console.log(`Patients service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
