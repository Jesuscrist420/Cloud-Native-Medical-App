import { PubSub, Subscription, Topic, Message } from '@google-cloud/pubsub';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { EventSchemas, type EventName, type EventPayload, type DomainEvent } from './events.js';

export type Handler<N extends EventName = EventName> = (event: DomainEvent<N>) => Promise<void> | void;
export type Handlers = Partial<{ [K in EventName]: Handler<K> }>;

export class EventBus {
  private pubsub: PubSub;
  private topics: Map<string, Topic> = new Map();
  private subscriptions: Map<string, Subscription> = new Map();

  constructor(opts?: { projectId?: string }) {
    this.pubsub = new PubSub({ projectId: opts?.projectId });
  }

  private getTopic(name: string): Topic {
    if (!this.topics.has(name)) this.topics.set(name, this.pubsub.topic(name));
    return this.topics.get(name)!;
  }

  private getSubscription(name: string): Subscription {
    if (!this.subscriptions.has(name)) this.subscriptions.set(name, this.pubsub.subscription(name));
    return this.subscriptions.get(name)!;
  }

  async ensureTopic(name: string) {
    const topic = this.getTopic(name);
    const [exists] = await topic.exists();
    if (!exists) await topic.create();
    return topic;
  }

  async ensureSubscription(topicName: string, subscriptionName: string) {
    const topic = await this.ensureTopic(topicName);
    const subscription = this.getSubscription(subscriptionName);
    const [exists] = await subscription.exists();
    if (!exists) await topic.createSubscription(subscriptionName);
    return subscription;
  }

  async publish<N extends EventName>(topicName: string, name: N, payload: EventPayload<N>, traceId?: string) {
    const schema: z.ZodTypeAny = (EventSchemas as any)[name];
    schema.parse(payload);
    const evt: DomainEvent<N> = {
      id: randomUUID(),
      name,
      payload,
      ts: new Date().toISOString(),
      traceId,
    };
    const topic = this.getTopic(topicName);
    const dataBuffer = Buffer.from(JSON.stringify(evt));
    const messageId = await topic.publishMessage({ data: dataBuffer, attributes: { eventName: name } });
    return { messageId, event: evt };
  }

  subscribe(subscriptionName: string, handlers: Handlers) {
    const subscription = this.getSubscription(subscriptionName);

    const onMessage = async (message: Message) => {
      try {
        const evt = JSON.parse(message.data.toString()) as DomainEvent;
        const handler = (handlers as any)[evt.name] as Handler | undefined;
        if (!handler) {
          // no handler for this event -> ack to avoid redelivery
          message.ack();
          return;
        }
        const schema: z.ZodTypeAny = (EventSchemas as any)[evt.name];
        schema.parse(evt.payload);
        await handler(evt as any);
        message.ack();
      } catch (err) {
        console.error('[EventBus] handler error', err);
        message.nack();
      }
    };

    const onError = (err: Error) => {
      console.error('[EventBus] subscription error', err);
    };

    subscription.on('message', onMessage);
    subscription.on('error', onError);

    return () => {
      subscription.removeListener('message', onMessage);
      subscription.removeListener('error', onError);
    };
  }
}

export function isEmulator(): boolean {
  return !!process.env.PUBSUB_EMULATOR_HOST;
}
