import { Firestore } from '@google-cloud/firestore';
import { Storage } from '@google-cloud/storage';

// Domain Model
export interface Doctor {
  id?: string;
  doctor_id: string;
  name: string;
  email: string;
  phone?: string;
  specialization: string;
  license_number: string;
  years_of_experience?: number;
  bio?: string;
  document_urls?: string[];
  created_at?: Date;
  updated_at?: Date;
}

// Repository Interface (DIP)
export interface IDoctorRepository {
  create(doctor: Omit<Doctor, 'id' | 'created_at' | 'updated_at'>): Promise<Doctor>;
  findById(doctorId: string): Promise<Doctor | null>;
  findByEmail(email: string): Promise<Doctor | null>;
  findBySpecialization(specialization: string): Promise<Doctor[]>;
  update(doctorId: string, data: Partial<Doctor>): Promise<Doctor | null>;
  delete(doctorId: string): Promise<boolean>;
  list(limit?: number): Promise<Doctor[]>;
}

// Firestore + Storage Implementation
export class FirestoreDoctorRepository implements IDoctorRepository {
  private db: Firestore;
  private storage: Storage;
  private collection: string = 'doctors';
  private bucketName: string;

  constructor(projectId?: string, bucketName?: string) {
    this.db = new Firestore({ projectId });
    this.storage = new Storage({ projectId });
    this.bucketName = bucketName || `${projectId}-doctors-documents`;
  }

  async create(doctor: Omit<Doctor, 'id' | 'created_at' | 'updated_at'>): Promise<Doctor> {
    try {
      const docRef = this.db.collection(this.collection).doc();
      const now = new Date();
      const doctorData = {
        ...doctor,
        created_at: now,
        updated_at: now,
      };
      await docRef.set(doctorData);
      
      return {
        id: docRef.id,
        ...doctorData,
      };
    } catch (error) {
      console.error('Failed to create doctor:', error);
      throw new Error('Firestore error while creating doctor');
    }
  }

  async findById(doctorId: string): Promise<Doctor | null> {
    try {
      // Try by document ID first
      const byId = await this.db.collection(this.collection).doc(doctorId).get();
      if (byId.exists) {
        return {
          id: byId.id,
          ...byId.data(),
        } as Doctor;
      }

      // Try by doctor_id field
      const snapshot = await this.db
        .collection(this.collection)
        .where('doctor_id', '==', doctorId)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return null;
      }
      
      const doc = snapshot.docs[0];
      return {
        id: doc.id,
        ...doc.data(),
      } as Doctor;
    } catch (error) {
      console.error('Failed to find doctor:', error);
      throw new Error('Firestore error while finding doctor by Id');
    }
  }

  async findByEmail(email: string): Promise<Doctor | null> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .where('email', '==', email)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return null;
      }
      
      const doc = snapshot.docs[0];
      return {
        id: doc.id,
        ...doc.data(),
      } as Doctor;
    } catch (error) {
      console.error('Failed to find doctor by email:', error);
      throw new Error('Firestore error while finding doctor by email');
    }
  }

  async findBySpecialization(specialization: string): Promise<Doctor[]> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .where('specialization', '==', specialization)
        .orderBy('name')
        .get();
      
      return snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      } as Doctor));
    } catch (error) {
      console.error('Failed to find doctors by specialization:', error);
      throw new Error('Firestore error while finding doctors');
    }
  }

  async update(doctorId: string, data: Partial<Doctor>): Promise<Doctor | null> {
    try {
      // Find document by doctor_id field
      const snapshot = await this.db
        .collection(this.collection)
        .where('doctor_id', '==', doctorId)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return null;
      }
      
      const docRef = snapshot.docs[0].ref;
      await docRef.update({
        ...data,
        updated_at: new Date(),
      });
      
      const updated = await docRef.get();
      return {
        id: updated.id,
        ...updated.data(),
      } as Doctor;
    } catch (error) {
      console.error('Failed to update doctor:', error);
      throw new Error('Firestore error while updating doctor');
    }
  }

  async delete(doctorId: string): Promise<boolean> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .where('doctor_id', '==', doctorId)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return false;
      }
      
      await snapshot.docs[0].ref.delete();
      return true;
    } catch (error) {
      console.error('Failed to delete doctor:', error);
      return false;
    }
  }

  async list(limit: number = 50): Promise<Doctor[]> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .orderBy('name')
        .limit(limit)
        .get();
      
      return snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      } as Doctor));
    } catch (error) {
      console.error('Failed to list doctors:', error);
      throw new Error('Firestore error while listing doctors');
    }
  }

  // Upload document to Cloud Storage
  async uploadDocument(doctorId: string, fileName: string, fileBuffer: Buffer): Promise<string> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${doctorId}/${fileName}`);
      
      await blob.save(fileBuffer, {
        metadata: {
          contentType: 'application/octet-stream',
        },
      });
      
      await blob.makePublic();
      
      return `https://storage.googleapis.com/${this.bucketName}/${doctorId}/${fileName}`;
    } catch (error) {
      console.error('Failed to upload document:', error);
      throw new Error('Storage error while uploading document');
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.db.collection(this.collection).limit(1).get();
      return true;
    } catch (error) {
      console.error('Firestore health check failed:', error);
      return false;
    }
  }
}
