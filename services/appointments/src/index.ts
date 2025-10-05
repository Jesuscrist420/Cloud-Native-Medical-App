import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common';

const PORT = process.env.PORT || 4002;
const TOPIC_APPOINTMENTS = process.env.TOPIC_APPOINTMENTS || 'appointments';

async function main() {
  const app = express();
  app.use(express.json());

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

  app.post('/appointments', async (req, res) => {
    try {
      const { appointmentId, patientId, doctorId, datetime } = req.body;
      await bus.publish(TOPIC_APPOINTMENTS, 'appointment.created', { appointmentId, patientId, doctorId, datetime });
      res.status(201).json({ ok: true, appointmentId });
    } catch (error) {
      console.error('Error publishing appointment:', error);
      res.status(500).json({ ok: false, error: 'Failed to publish appointment' });
    }
  });

  app.get('/healthz', (_req, res) => res.json({ ok: true }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
