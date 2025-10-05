import pg from 'pg';

const { Pool } = pg;

// Domain Model
export interface Payment {
  id?: number;
  payment_id: string;
  appointment_id: string;
  amount: number;
  currency: string;
  status: 'pending' | 'completed' | 'failed' | 'refunded';
  payment_method?: string;
  transaction_id?: string;
  created_at?: Date;
  updated_at?: Date;
}

// Repository Interface (DIP)
export interface IPaymentRepository {
  create(payment: Omit<Payment, 'id' | 'created_at' | 'updated_at'>): Promise<Payment>;
  findById(paymentId: string): Promise<Payment | null>;
  findByAppointmentId(appointmentId: string): Promise<Payment[]>;
  updateStatus(paymentId: string, status: Payment['status'], transactionId?: string): Promise<Payment | null>;
}

// PostgreSQL Implementation
export class PostgresPaymentRepository implements IPaymentRepository {
  private pool: pg.Pool;

  constructor(config: {
    host?: string;
    database?: string;
    user?: string;
    password?: string;
    port?: number;
  }) {
    this.pool = new Pool({
      host: config.host || 'localhost',
      database: config.database || 'payments',
      user: config.user || 'postgres',
      password: config.password,
      port: config.port || 5432,
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    this.pool.on('error', (err: Error) => {
      console.error('Unexpected error on idle client', err);
    });
  }

  async create(payment: Omit<Payment, 'id' | 'created_at' | 'updated_at'>): Promise<Payment> {
    const query = `
      INSERT INTO payments (payment_id, appointment_id, amount, currency, status, payment_method, transaction_id)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;
    const values = [
      payment.payment_id,
      payment.appointment_id,
      payment.amount,
      payment.currency,
      payment.status,
      payment.payment_method || null,
      payment.transaction_id || null,
    ];

    try {
      const result = await this.pool.query(query, values);
      return result.rows[0];
    } catch (error) {
      console.error('Failed to create payment:', error);
      throw new Error('Database error while creating payment');
    }
  }

  async findById(paymentId: string): Promise<Payment | null> {
    const query = 'SELECT * FROM payments WHERE payment_id = $1';
    try {
      const result = await this.pool.query(query, [paymentId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Failed to find payment:', error);
      throw new Error('Database error while finding payment by Id');
    }
  }

  async findByAppointmentId(appointmentId: string): Promise<Payment[]> {
    const query = 'SELECT * FROM payments WHERE appointment_id = $1 ORDER BY created_at DESC';
    try {
      const result = await this.pool.query(query, [appointmentId]);
      return result.rows;
    } catch (error) {
      console.error('Failed to find payments by appointment:', error);
      throw new Error('Database error while finding payments by appointment');
    }
  }

  async updateStatus(paymentId: string, status: Payment['status'], transactionId?: string): Promise<Payment | null> {
    const query = `
      UPDATE payments 
      SET status = $1, transaction_id = COALESCE($2, transaction_id), updated_at = NOW()
      WHERE payment_id = $3
      RETURNING *
    `;
    try {
      const result = await this.pool.query(query, [status, transactionId || null, paymentId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Failed to update payment status:', error);
      throw new Error('Database error while updating payment');
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch (error) {
      console.error('Database health check failed:', error);
      return false;
    }
  }
}
