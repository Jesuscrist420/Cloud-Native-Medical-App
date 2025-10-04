import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common/pubsub.js';

const PORT = process.env.PORT || 4002;
const TOPIC_APPOINTMENTS = process.env.TOPIC_APPOINTMENTS || 'appointments';

async function main() {
  const app = express();
  app.use(express.json());

  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  await bus.ensureTopic(TOPIC_APPOINTMENTS);

  app.post('/appointments', async (req, res) => {
    const { appointmentId, patientId, doctorId, datetime } = req.body;
    await bus.publish(TOPIC_APPOINTMENTS, 'appointment.created', { appointmentId, patientId, doctorId, datetime });
    res.status(201).json({ ok: true, appointmentId });
  });

  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  app.listen(PORT, () => console.log(`Appointments service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
