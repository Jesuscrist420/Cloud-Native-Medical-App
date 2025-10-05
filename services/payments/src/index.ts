import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common';

const PORT = process.env.PORT || 4003;
const TOPIC_PAYMENTS = process.env.TOPIC_PAYMENTS || 'payments';

async function main() {
  const app = express();
  app.use(express.json());

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

  app.post('/payments', async (req, res) => {
    try {
      const { appointmentId, amount, currency = 'USD' } = req.body;
      const paymentId = `pay_${Date.now()}`;
      await bus.publish(TOPIC_PAYMENTS, 'payment.completed', { paymentId, appointmentId, amount, currency });
      res.status(201).json({ ok: true, paymentId });
    } catch (error) {
      console.error('Error publishing payment:', error);
      res.status(500).json({ ok: false, error: 'Failed to publish payment' });
    }
  });

  app.get('/healthz', (_req, res) => res.json({ ok: true }));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
