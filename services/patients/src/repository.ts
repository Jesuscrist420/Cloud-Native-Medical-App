import { Firestore } from '@google-cloud/firestore';
import { Storage } from '@google-cloud/storage';

// Domain Model
export interface Patient {
  id?: string;
  patient_id: string;
  name: string;
  email: string;
  phone?: string;
  date_of_birth?: string;
  address?: string;
  medical_history?: string;
  document_urls?: string[];
  created_at?: Date;
  updated_at?: Date;
}

// Repository Interface (DIP)
export interface IPatientRepository {
  create(patient: Omit<Patient, 'id' | 'created_at' | 'updated_at'>): Promise<Patient>;
  findById(patientId: string): Promise<Patient | null>;
  findByEmail(email: string): Promise<Patient | null>;
  update(patientId: string, data: Partial<Patient>): Promise<Patient | null>;
  delete(patientId: string): Promise<boolean>;
  list(limit?: number): Promise<Patient[]>;
}

// Firestore + Storage Implementation
export class FirestorePatientRepository implements IPatientRepository {
  private db: Firestore;
  private storage: Storage;
  private collection: string = 'patients';
  private bucketName: string;

  constructor(projectId?: string, bucketName?: string) {
    this.db = new Firestore({ projectId });
    this.storage = new Storage({ projectId });
    this.bucketName = bucketName || `${projectId}-patients-documents`;
  }

  async create(patient: Omit<Patient, 'id' | 'created_at' | 'updated_at'>): Promise<Patient> {
    try {
      const docRef = this.db.collection(this.collection).doc();
      const now = new Date();
      const patientData = {
        ...patient,
        created_at: now,
        updated_at: now,
      };
      await docRef.set(patientData);
      
      return {
        id: docRef.id,
        ...patientData,
      };
    } catch (error) {
      console.error('Failed to create patient:', error);
      throw new Error('Firestore error while creating patient');
    }
  }

  async findById(patientId: string): Promise<Patient | null> {
    try {
      // Try by document ID first
      const byId = await this.db.collection(this.collection).doc(patientId).get();
      if (byId.exists) {
        return {
          id: byId.id,
          ...byId.data(),
        } as Patient;
      }

      // Try by patient_id field
      const snapshot = await this.db
        .collection(this.collection)
        .where('patient_id', '==', patientId)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return null;
      }
      
      const doc = snapshot.docs[0];
      return {
        id: doc.id,
        ...doc.data(),
      } as Patient;
    } catch (error) {
      console.error('Failed to find patient:', error);
      throw new Error('Firestore error while finding patient by Id');
    }
  }

  async findByEmail(email: string): Promise<Patient | null> {
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
      } as Patient;
    } catch (error) {
      console.error('Failed to find patient by email:', error);
      throw new Error('Firestore error while finding patient by email');
    }
  }

  async update(patientId: string, data: Partial<Patient>): Promise<Patient | null> {
    try {
      // Find document by patient_id field
      const snapshot = await this.db
        .collection(this.collection)
        .where('patient_id', '==', patientId)
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
      } as Patient;
    } catch (error) {
      console.error('Failed to update patient:', error);
      throw new Error('Firestore error while updating patient');
    }
  }

  async delete(patientId: string): Promise<boolean> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .where('patient_id', '==', patientId)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return false;
      }
      
      await snapshot.docs[0].ref.delete();
      return true;
    } catch (error) {
      console.error('Failed to delete patient:', error);
      return false;
    }
  }

  async list(limit: number = 50): Promise<Patient[]> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .orderBy('created_at', 'desc')
        .limit(limit)
        .get();
      
      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      } as Patient));
    } catch (error) {
      console.error('Failed to list patients:', error);
      throw new Error('Firestore error while listing patients');
    }
  }

  // Upload document to Cloud Storage
  async uploadDocument(patientId: string, fileName: string, fileBuffer: Buffer): Promise<string> {
    try {
      const bucket = this.storage.bucket(this.bucketName);
      const blob = bucket.file(`${patientId}/${fileName}`);
      
      await blob.save(fileBuffer, {
        metadata: {
          contentType: 'application/octet-stream',
        },
      });
      
      // Make file publicly readable (adjust based on your security requirements)
      await blob.makePublic();
      
      return `https://storage.googleapis.com/${this.bucketName}/${patientId}/${fileName}`;
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
