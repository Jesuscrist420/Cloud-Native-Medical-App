import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common';

const PORT = process.env.PORT || 4004;
const TOPIC = process.env.TOPIC_NOTIFICATIONS || 'notifications';
const SUBSCRIPTION = process.env.SUB_NOTIFICATIONS || 'notifications-service';

async function main() {
  const app = express();
  app.use(express.json());

  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  await bus.ensureTopic(TOPIC);
  await bus.ensureSubscription(TOPIC, SUBSCRIPTION);

  // Health
  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  // In a real app, we would integrate with email/SMS providers here.
  bus.subscribe(SUBSCRIPTION, {
    'notification.send': async (evt) => {
      console.log(`[notifications] sending ${evt.payload.channel} to ${evt.payload.to} using template ${evt.payload.template}`);
      // simulate send success
    }
  });

  app.listen(PORT, () => console.log(`Notifications service on :${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
