import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common/pubsub.js';

const PORT = process.env.PORT || 4003;
const TOPIC_PAYMENTS = process.env.TOPIC_PAYMENTS || 'payments';

async function main() {
  const app = express();
  app.use(express.json());

  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  await bus.ensureTopic(TOPIC_PAYMENTS);

  app.post('/payments', async (req, res) => {
    const { appointmentId, amount, currency = 'USD' } = req.body;
    const paymentId = `pay_${Date.now()}`;
    await bus.publish(TOPIC_PAYMENTS, 'payment.completed', { paymentId, appointmentId, amount, currency });
    res.status(201).json({ ok: true, paymentId });
  });

  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  app.listen(PORT, () => console.log(`Payments service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
