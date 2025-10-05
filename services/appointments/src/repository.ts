import pg from 'pg';

const { Pool } = pg;

// Domain Model (DIP - depend on abstractions)
export interface Appointment {
  id?: number;
  appointment_id: string;
  patient_id: string;
  doctor_id: string;
  appointment_date: string;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
  notes?: string;
  created_at?: Date;
  updated_at?: Date;
}

// Repository Interface (DIP - high-level abstraction)
export interface IAppointmentRepository {
  create(appointment: Omit<Appointment, 'id' | 'created_at' | 'updated_at'>): Promise<Appointment>;
  findById(appointmentId: string): Promise<Appointment | null>;
  findByPatientId(patientId: string): Promise<Appointment[]>;
  findByDoctorId(doctorId: string): Promise<Appointment[]>;
  updateStatus(appointmentId: string, status: Appointment['status']): Promise<Appointment | null>;
  delete(appointmentId: string): Promise<boolean>;
}

// PostgreSQL Implementation (DIP - low-level details)
export class PostgresAppointmentRepository implements IAppointmentRepository {
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
      database: config.database || 'appointments',
      user: config.user || 'postgres',
      password: config.password,
      port: config.port || 5432,
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    // Handle pool errors
    this.pool.on('error', (err) => {
      console.error('Unexpected error on idle client', err);
    });
  }

  async create(appointment: Omit<Appointment, 'id' | 'created_at' | 'updated_at'>): Promise<Appointment> {
    const query = `
      INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_date, status, notes)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    const values = [
      appointment.appointment_id,
      appointment.patient_id,
      appointment.doctor_id,
      appointment.appointment_date,
      appointment.status,
      appointment.notes || null,
    ];

    try {
      const result = await this.pool.query(query, values);
      return result.rows[0];
    } catch (error) {
      console.error('Failed to create appointment:', error);
      throw new Error('Database error while creating appointment');
    }
  }

  async findById(appointmentId: string): Promise<Appointment | null> {
    const query = 'SELECT * FROM appointments WHERE appointment_id = $1';
    try {
      const result = await this.pool.query(query, [appointmentId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Failed to find appointment:', error);
      throw new Error('Database error while finding appointment by Id');
    }
  }

  async findByPatientId(patientId: string): Promise<Appointment[]> {
    const query = 'SELECT * FROM appointments WHERE patient_id = $1 ORDER BY appointment_date DESC';
    try {
      const result = await this.pool.query(query, [patientId]);
      return result.rows;
    } catch (error) {
      console.error('Failed to find appointments by patient:', error);
      throw new Error('Database error while finding appointments by patient');
    }
  }

  async findByDoctorId(doctorId: string): Promise<Appointment[]> {
    const query = 'SELECT * FROM appointments WHERE doctor_id = $1 ORDER BY appointment_date DESC';
    try {
      const result = await this.pool.query(query, [doctorId]);
      return result.rows;
    } catch (error) {
      console.error('Failed to find appointments by doctor:', error);
      throw new Error('Database error while finding appointments by doctor');
    }
  }

  async updateStatus(appointmentId: string, status: Appointment['status']): Promise<Appointment | null> {
    const query = `
      UPDATE appointments 
      SET status = $1, updated_at = NOW()
      WHERE appointment_id = $2
      RETURNING *
    `;
    try {
      const result = await this.pool.query(query, [status, appointmentId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Failed to update appointment status:', error);
      throw new Error('Database error while updating appointment');
    }
  }

  async delete(appointmentId: string): Promise<boolean> {
    const query = 'DELETE FROM appointments WHERE appointment_id = $1';
    try {
      const result = await this.pool.query(query, [appointmentId]);
      return (result.rowCount ?? 0) > 0;
    } catch (error) {
      console.error('Failed to delete appointment:', error);
      throw new Error('Database error while deleting appointment');
    }
  }

  // Graceful shutdown
  async close(): Promise<void> {
    await this.pool.end();
  }

  // Health check
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
