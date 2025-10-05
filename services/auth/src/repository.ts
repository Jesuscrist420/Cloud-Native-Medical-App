import { Firestore } from '@google-cloud/firestore';

// Domain Model
export interface User {
  id?: string;
  email: string;
  password_hash: string;
  role: 'patient' | 'doctor' | 'admin';
  created_at?: Date;
  updated_at?: Date;
}

export interface Session {
  id?: string;
  user_id: string;
  token: string;
  expires_at: Date;
  created_at?: Date;
}

// Repository Interface (DIP)
export interface IUserRepository {
  create(user: Omit<User, 'id' | 'created_at' | 'updated_at'>): Promise<User>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  update(id: string, data: Partial<User>): Promise<User | null>;
}

export interface ISessionRepository {
  create(session: Omit<Session, 'id' | 'created_at'>): Promise<Session>;
  findByToken(token: string): Promise<Session | null>;
  delete(id: string): Promise<boolean>;
}

// Firestore Implementation
export class FirestoreUserRepository implements IUserRepository {
  private db: Firestore;
  private collection: string = 'users';

  constructor(projectId?: string) {
    this.db = new Firestore({
      projectId,
    });
  }

  async create(user: Omit<User, 'id' | 'created_at' | 'updated_at'>): Promise<User> {
    try {
      const docRef = this.db.collection(this.collection).doc();
      const now = new Date();
      const userData = {
        ...user,
        created_at: now,
        updated_at: now,
      };
      await docRef.set(userData);
      
      return {
        id: docRef.id,
        ...userData,
      };
    } catch (error) {
      console.error('Failed to create user:', error);
      throw new Error('Firestore error while creating user');
    }
  }

  async findById(id: string): Promise<User | null> {
    try {
      const doc = await this.db.collection(this.collection).doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return {
        id: doc.id,
        ...doc.data(),
      } as User;
    } catch (error) {
      console.error('Failed to find user by ID:', error);
      throw new Error('Firestore error while finding user');
    }
  }

  async findByEmail(email: string): Promise<User | null> {
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
      } as User;
    } catch (error) {
      console.error('Failed to find user by email:', error);
      throw new Error('Firestore error while finding user');
    }
  }

  async update(id: string, data: Partial<User>): Promise<User | null> {
    try {
      const docRef = this.db.collection(this.collection).doc(id);
      await docRef.update({
        ...data,
        updated_at: new Date(),
      });
      
      const updated = await docRef.get();
      if (!updated.exists) {
        return null;
      }
      
      return {
        id: updated.id,
        ...updated.data(),
      } as User;
    } catch (error) {
      console.error('Failed to update user:', error);
      throw new Error('Firestore error while updating user');
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

export class FirestoreSessionRepository implements ISessionRepository {
  private db: Firestore;
  private collection: string = 'sessions';

  constructor(projectId?: string) {
    this.db = new Firestore({
      projectId,
    });
  }

  async create(session: Omit<Session, 'id' | 'created_at'>): Promise<Session> {
    try {
      const docRef = this.db.collection(this.collection).doc();
      const sessionData = {
        ...session,
        created_at: new Date(),
      };
      await docRef.set(sessionData);
      
      return {
        id: docRef.id,
        ...sessionData,
      };
    } catch (error) {
      console.error('Failed to create session:', error);
      throw new Error('Firestore error while creating session');
    }
  }

  async findByToken(token: string): Promise<Session | null> {
    try {
      const snapshot = await this.db
        .collection(this.collection)
        .where('token', '==', token)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        return null;
      }
      
      const doc = snapshot.docs[0];
      return {
        id: doc.id,
        ...doc.data(),
      } as Session;
    } catch (error) {
      console.error('Failed to find session by token:', error);
      throw new Error('Firestore error while finding session');
    }
  }

  async delete(id: string): Promise<boolean> {
    try {
      await this.db.collection(this.collection).doc(id).delete();
      return true;
    } catch (error) {
      console.error('Failed to delete session:', error);
      return false;
    }
  }
}
