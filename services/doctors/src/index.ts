import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { FirestoreDoctorRepository } from './repository.js';
import { z } from 'zod';

const PORT = process.env.PORT || 4006;

// Input validation schemas
const CreateDoctorSchema = z.object({
  doctorId: z.string(),
  name: z.string(),
  email: z.string().email(),
  phone: z.string().optional(),
  specialization: z.string(),
  licenseNumber: z.string(),
  yearsOfExperience: z.number().optional(),
  bio: z.string().optional(),
});

const UpdateDoctorSchema = z.object({
  name: z.string().optional(),
  phone: z.string().optional(),
  specialization: z.string().optional(),
  yearsOfExperience: z.number().optional(),
  bio: z.string().optional(),
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
  const repository = new FirestoreDoctorRepository(
    process.env.GOOGLE_CLOUD_PROJECT,
    process.env.DOCTORS_BUCKET
  );

  // CREATE doctor
  app.post('/doctors', async (req, res) => {
    try {
      // 1. Validate input
      const validated = CreateDoctorSchema.parse(req.body);
      
      // 2. Check if doctor already exists
      const existingDoctor = await repository.findByEmail(validated.email);
      if (existingDoctor) {
        return res.status(409).json({ ok: false, error: 'Doctor with this email already exists' });
      }
      
      // 3. Create doctor
      const doctor = await repository.create({
        doctor_id: validated.doctorId,
        name: validated.name,
        email: validated.email,
        phone: validated.phone,
        specialization: validated.specialization,
        license_number: validated.licenseNumber,
        years_of_experience: validated.yearsOfExperience,
        bio: validated.bio,
      });
      
      res.status(201).json({ ok: true, doctor });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error creating doctor:', error);
      res.status(500).json({ ok: false, error: 'Failed to create doctor' });
    }
  });

  // GET doctor by ID
  app.get('/doctors/:id', async (req, res) => {
    try {
      const doctor = await repository.findById(req.params.id);
      if (!doctor) {
        return res.status(404).json({ ok: false, error: 'Doctor not found by Id' });
      }
      res.json({ ok: true, doctor });
    } catch (error) {
      console.error('Error fetching doctor:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch doctor' });
    }
  });

  // GET doctor by email
  app.get('/doctors/email/:email', async (req, res) => {
    try {
      const doctor = await repository.findByEmail(req.params.email);
      if (!doctor) {
        return res.status(404).json({ ok: false, error: 'Doctor not found by email' });
      }
      res.json({ ok: true, doctor });
    } catch (error) {
      console.error('Error fetching doctor:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch doctor' });
    }
  });

  // GET doctors by specialization
  app.get('/doctors/specialization/:specialization', async (req, res) => {
    try {
      const doctors = await repository.findBySpecialization(req.params.specialization);
      res.json({ ok: true, doctors });
    } catch (error) {
      console.error('Error fetching doctors:', error);
      res.status(500).json({ ok: false, error: 'Failed to fetch doctors by specialization' });
    }
  });

  // LIST doctors
  app.get('/doctors', async (req, res) => {
    try {
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 50;
      const doctors = await repository.list(limit);
      res.json({ ok: true, doctors });
    } catch (error) {
      console.error('Error listing doctors:', error);
      res.status(500).json({ ok: false, error: 'Failed to list doctors' });
    }
  });

  // UPDATE doctor
  app.patch('/doctors/:id', async (req, res) => {
    try {
      const validated = UpdateDoctorSchema.parse(req.body);
      const doctor = await repository.update(req.params.id, validated);
      
      if (!doctor) {
        return res.status(404).json({ ok: false, error: 'Doctor not found' });
      }
      
      res.json({ ok: true, doctor });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error updating doctor:', error);
      res.status(500).json({ ok: false, error: 'Failed to update doctor' });
    }
  });

  // DELETE doctor
  app.delete('/doctors/:id', async (req, res) => {
    try {
      const deleted = await repository.delete(req.params.id);
      if (!deleted) {
        return res.status(404).json({ ok: false, error: 'Doctor not found' });
      }
      res.json({ ok: true, message: 'Doctor deleted' });
    } catch (error) {
      console.error('Error deleting doctor:', error);
      res.status(500).json({ ok: false, error: 'Failed to delete doctor' });
    }
  });

  // Health check
  app.get('/doctors/healthz', async (_req, res) => {
    const dbHealthy = await repository.healthCheck();
    if (!dbHealthy) {
      return res.status(503).json({ ok: false, error: 'Database unhealthy' });
    }
    res.json({ ok: true });
  });

  app.listen(PORT, () => console.log(`Doctors service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
