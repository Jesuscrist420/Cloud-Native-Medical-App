import { z } from 'zod';

// Canonical event names and payload schemas
export const EventSchemas = {
  'appointment.created': z.object({
    appointmentId: z.string(),
    patientId: z.string(),
    doctorId: z.string(),
    datetime: z.string(), // ISO
  }),
  'appointment.cancelled': z.object({
    appointmentId: z.string(),
    reason: z.string().optional()
  }),
  'payment.completed': z.object({
    paymentId: z.string(),
    appointmentId: z.string(),
    amount: z.number(),
    currency: z.string().default('USD')
  }),
  'payment.failed': z.object({
    paymentId: z.string(),
    appointmentId: z.string(),
    reason: z.string()
  }),
  'notification.send': z.object({
    to: z.string(),
    channel: z.enum(['email','sms','push']),
    template: z.string(),
    data: z.record(z.any())
  })
} as const;

export type EventName = keyof typeof EventSchemas;
export type EventPayload<N extends EventName> = z.infer<typeof EventSchemas[N]>;

export interface DomainEvent<N extends EventName = EventName> {
  name: N;
  payload: EventPayload<N>;
  id: string;
  ts: string; // ISO timestamp
  traceId?: string;
}
