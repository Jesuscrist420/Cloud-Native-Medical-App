import 'dotenv/config';
import express from 'express';
import { EventBus } from '@app/common';

const PORT = process.env.PORT || 4004;
const TOPIC = process.env.TOPIC_NOTIFICATIONS || 'notifications';
const SUBSCRIPTION = process.env.SUB_NOTIFICATIONS || 'notifications-service';

// Notification counters for monitoring
const stats = {
  processed: 0,
  failed: 0,
  byChannel: {
    email: 0,
    sms: 0,
    push: 0,
  }
};

async function main() {
  const app = express();
  app.use(express.json());

  // Health check
  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  // Stats endpoint for monitoring
  app.get('/stats', (_req, res) => res.json({ ok: true, stats }));

  // Start HTTP server first to pass health checks
  const server = app.listen(PORT, () => console.log(`🚀 Notifications service on :${PORT}`));

  // Initialize Pub/Sub after server is listening
  const bus = new EventBus({ projectId: process.env.GOOGLE_CLOUD_PROJECT });
  
  let unsubscribe: (() => void) | null = null;

  try {
    await bus.ensureTopic(TOPIC);
    await bus.ensureSubscription(TOPIC, SUBSCRIPTION);
    console.log(`✅ Pub/Sub subscription ${SUBSCRIPTION} ready`);
    
    // Subscribe to notification events with active message pulling
    unsubscribe = bus.subscribe(SUBSCRIPTION, {
      'notification.send': async (evt) => {
        const { to, channel, template, data } = evt.payload;
        
        try {
          console.log(`📧 [${evt.id}] Sending ${channel} notification to ${to}`);
          console.log(`   Template: ${template}`);
          console.log(`   Data:`, JSON.stringify(data, null, 2));
          
          // Simulate notification sending based on channel
          switch (channel) {
            case 'email':
              await sendEmail(to, template, data);
              break;
            case 'sms':
              await sendSMS(to, template, data);
              break;
            case 'push':
              await sendPushNotification(to, template, data);
              break;
            default:
              console.warn(`⚠️  Unknown notification channel: ${channel}`);
          }
          
          // Update stats
          stats.processed++;
          stats.byChannel[channel] = (stats.byChannel[channel] || 0) + 1;
          
          console.log(`✅ [${evt.id}] Notification sent successfully`);
        } catch (error) {
          stats.failed++;
          console.error(`❌ [${evt.id}] Failed to send notification:`, error);
          throw error; // Re-throw to trigger message nack and retry
        }
      },
      
      // Handle appointment-related notifications
      'appointment.created': async (evt) => {
        console.log(`📅 Appointment created notification: ${evt.payload.appointmentId}`);
        // Could trigger automatic notifications here
      },
      
      'appointment.cancelled': async (evt) => {
        console.log(`🚫 Appointment cancelled notification: ${evt.payload.appointmentId}`);
        // Could trigger cancellation notifications here
      },
      
      // Handle payment-related notifications
      'payment.completed': async (evt) => {
        console.log(`💳 Payment completed notification: ${evt.payload.paymentId}`);
        // Could trigger payment confirmation notifications here
      },
      
      'payment.failed': async (evt) => {
        console.log(`💥 Payment failed notification: ${evt.payload.paymentId}`);
        // Could trigger payment failure notifications here
      }
    });
    
    console.log(`🔔 Actively listening for notification messages...`);
    console.log(`📊 Stats available at: http://localhost:${PORT}/stats`);
    
  } catch (error) {
    console.error('❌ Failed to initialize Pub/Sub:', error);
    // Don't exit - let service run for health checks
  }

  // Graceful shutdown
  process.on('SIGTERM', async () => {
    console.log('⚠️  SIGTERM received, closing connections...');
    
    if (unsubscribe) {
      console.log('🔌 Unsubscribing from Pub/Sub...');
      unsubscribe();
    }
    
    server.close(() => {
      console.log('👋 Server closed');
      process.exit(0);
    });
  });
}

// Simulated notification sending functions
// In production, these would integrate with real services (SendGrid, Twilio, FCM, etc.)

async function sendEmail(to: string, template: string, data: Record<string, any>): Promise<void> {
  // Simulate email sending delay
  await new Promise(resolve => setTimeout(resolve, 100));
  
  console.log(`   📨 Email sent to: ${to}`);
  console.log(`   📧 Subject: ${template}`);
  
  // In production:
  // await sendgrid.send({ to, template, dynamic_template_data: data });
}

async function sendSMS(to: string, template: string, data: Record<string, any>): Promise<void> {
  // Simulate SMS sending delay
  await new Promise(resolve => setTimeout(resolve, 100));
  
  console.log(`   📱 SMS sent to: ${to}`);
  console.log(`   💬 Message: ${template}`);
  
  // In production:
  // await twilio.messages.create({ to, body: template, from: TWILIO_NUMBER });
}

async function sendPushNotification(to: string, template: string, data: Record<string, any>): Promise<void> {
  // Simulate push notification delay
  await new Promise(resolve => setTimeout(resolve, 100));
  
  console.log(`   🔔 Push notification sent to: ${to}`);
  console.log(`   📲 Title: ${template}`);
  
  // In production:
  // await admin.messaging().send({ token: to, notification: { title: template, body: data.body } });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
