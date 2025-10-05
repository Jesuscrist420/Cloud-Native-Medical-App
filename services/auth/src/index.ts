import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { FirestoreUserRepository, FirestoreSessionRepository } from './repository.js';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const PORT = process.env.PORT || 4001;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const SALT_ROUNDS = 10;

// Input validation schemas
const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(['patient', 'doctor', 'admin']).default('patient'),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
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

  // Initialize repositories
  const userRepo = new FirestoreUserRepository(process.env.GOOGLE_CLOUD_PROJECT);
  const sessionRepo = new FirestoreSessionRepository(process.env.GOOGLE_CLOUD_PROJECT);

  // REGISTER new user
  app.post('/auth/register', async (req, res) => {
    try {
      // 1. Validate input
      const validated = RegisterSchema.parse(req.body);
      
      // 2. Check if user already exists
      const existingUser = await userRepo.findByEmail(validated.email);
      if (existingUser) {
        return res.status(409).json({ ok: false, error: 'User already exists' });
      }
      
      // 3. Hash password
      const passwordHash = await bcrypt.hash(validated.password, SALT_ROUNDS);
      
      // 4. Create user
      const user = await userRepo.create({
        email: validated.email,
        password_hash: passwordHash,
        role: validated.role,
      });
      
      // 5. Generate JWT token
      const token = jwt.sign(
        { userId: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '24h' }
      );
      
      // 6. Store session
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      await sessionRepo.create({
        user_id: user.id!,
        token,
        expires_at: expiresAt,
      });
      
      res.status(201).json({
        ok: true,
        user: { id: user.id, email: user.email, role: user.role },
        token,
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error registering user:', error);
      res.status(500).json({ ok: false, error: 'Failed to register user' });
    }
  });

  // LOGIN user
  app.post('/auth/login', async (req, res) => {
    try {
      // 1. Validate input
      const validated = LoginSchema.parse(req.body);
      
      // 2. Find user by email
      const user = await userRepo.findByEmail(validated.email);
      if (!user) {
        return res.status(401).json({ ok: false, error: 'Invalid username' });
      }
      
      // 3. Verify password
      const passwordValid = await bcrypt.compare(validated.password, user.password_hash);
      if (!passwordValid) {
        return res.status(401).json({ ok: false, error: 'Invalid password' });
      }
      
      // 4. Generate JWT token
      const token = jwt.sign(
        { userId: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '24h' }
      );
      
      // 5. Store session
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      await sessionRepo.create({
        user_id: user.id!,
        token,
        expires_at: expiresAt,
      });
      
      res.json({
        ok: true,
        user: { id: user.id, email: user.email, role: user.role },
        token,
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: 'Validation failed', details: error.errors });
      }
      console.error('Error logging in:', error);
      res.status(500).json({ ok: false, error: 'Failed to login' });
    }
  });

  // LOGOUT user
  app.post('/auth/logout', async (req, res) => {
    try {
      const token = req.headers.authorization?.replace('Bearer ', '');
      if (!token) {
        return res.status(401).json({ ok: false, error: 'No token provided' });
      }
      
      await sessionRepo.delete(token);
      res.json({ ok: true, message: 'Logged out successfully' });
    } catch (error) {
      console.error('Error logging out:', error);
      res.status(500).json({ ok: false, error: 'Failed to logout' });
    }
  });

  // VERIFY token
  app.get('/auth/verify', async (req, res) => {
    try {
      const token = req.headers.authorization?.replace('Bearer ', '');
      if (!token) {
        return res.status(401).json({ ok: false, error: 'No token provided' });
      }
      
      // Check session exists
      const session = await sessionRepo.findByToken(token);
      if (!session) {
        return res.status(401).json({ ok: false, error: 'Invalid token' });
      }
      
      // Verify JWT
      const decoded = jwt.verify(token, JWT_SECRET) as any;
      
      res.json({ ok: true, user: decoded });
    } catch (error) {
      console.error('Error verifying token:', error);
      res.status(401).json({ ok: false, error: 'Invalid or expired token' });
    }
  });

  // Health check
  app.get('/auth/healthz', async (_req, res) => {
    const dbHealthy = await userRepo.healthCheck();
    if (!dbHealthy) {
      return res.status(503).json({ ok: false, error: 'Database unhealthy' });
    }
    res.json({ ok: true });
  });

  app.listen(PORT, () => console.log(`Auth service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
