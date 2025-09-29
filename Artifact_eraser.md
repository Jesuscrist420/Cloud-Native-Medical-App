# Artifact V1 Eraser

## Team

- Camilo Andres Pinzon Ruiz
- Miguel Angel Ortiz Escobar
- Omar Leonardo Zambrano Pulgarin
- Jesus Ernesto Quiñones Cely

## Software System
- **Name**: Artifact V1 Eraser
- **Logo**: **Pending**
- **Description**: Software system for medical appointments management.
    - **Domain**: Healthcare
    - **Purpose**: To manage medical appointments efficiently.
    - **Main Functionalities**: Scheduling, Payments, Notifications, Patient & Doctors Records.
- **Cloud-Native Principles**:
    - Containerization
    - Scalability
    - High Availability
    - Resilience
    - Elasticity
    - Automation
    - Observability
    - Loose Coupling
    - Microservices & Event Driven Architecture
    - Continuous Integration/Continuous Deployment (CI/CD)

## Software Design

### Architectural Design
- #### C&C
    - Graph
    <img src="C&C Light.png" alt="Alt text">
    - **Frontend**: User interface for patients and doctors to interact with the system.

    - **API Gateway**: Routes requests to appropriate services and handles cross-cutting concerns.

    - **Auth Service**: Manages user authentication and authorization.

    - **Appointment Service**: Handles scheduling and managing medical appointments.

    - **Payment Service**: Processes payments for appointments.
    
    - **Patient Service**: Manages patient records and information.
    
    - **Doctor Service**: Manages doctor records and information.
    
    - **Event Bus**: Facilitates communication between microservices using events.
    
    - **Notification Service**: Sends notifications to patients and doctors.
    
    - **Reporting / Analytics Service**: Generates reports and analytics on appointments and payments.
    
    - **Databases**: Stores all persistent data for the services.

---

- #### Deployment Structure
    - Graph
    <img src="Deployment View Light.png" alt="Alt text">
        
    - **Load Balancer:** Distributes incoming HTTP/HTTPS traffic across frontend and backend services.
        - Cloud Service: Google Cloud Load Balancing.

    - **Frontend Hosting:** Delivers static content (HTML, CSS, JS) for the web application.

        - Cloud Service: Firebase Hosting or Cloud Storage + Cloud CDN.

    - **API Gateway:** Provides a unified entry point to backend microservices, handling authentication, rate limiting, and routing.

        - Cloud Service: Apigee API Gateway or Cloud Endpoints.

    - **Microservices Runtime:** Executes containerized backend services (Auth, Appointment, Payment, Patient, Doctor, Notifications, Reporting).

        - Cloud Service: Cloud Run (serverless containers) or Google Kubernetes Engine (GKE).

    - **Event Bus:** Enables asynchronous communication between microservices via pub/sub messaging.

        - Cloud Service: Google Cloud Pub/Sub.

    - **Databases:** Stores structured and unstructured data for patients, doctors, appointments, and payments.

        - Cloud Services: Cloud SQL (PostgreSQL/MySQL) for relational data, Firestore for NoSQL data.

    - **File Storage:** Stores documents, images, and reports.

        - Cloud Service: Cloud Storage.

    - **Authentication & Identity:** Manages user authentication and authorization, supporting secure login and role-based access.

        - Cloud Service: Google Identity Platform.

    - **Observability (Monitoring & Logging):** Collects logs, metrics, and traces to monitor system health and performance.

        - Cloud Services: Cloud Monitoring, Cloud Logging, Cloud Trace.

    - **Secrets Management:** Stores and manages sensitive data such as API keys, certificates, and credentials.

        - Cloud Service: Secret Manager.

---

### Detailed Design

#### Data Model(s)
##### Relational (Google Cloud SQL – PostgreSQL)
Used for structured information with strong relationships (appointments, payments, users).

- **Appointment Table**
  - **Fields**: appointmentId (PK), patientId (FK), doctorId (FK), date, time, status (scheduled, completed, cancelled), paymentId (FK).  
  - **Responsibility**: Manages the lifecycle of medical appointments.  

- **Payment Table**
  - **Fields**: paymentId (PK), appointmentId (FK), amount, method (credit card, debit, insurance), status (pending, completed, failed), transactionRef.  
  - **Responsibility**: Records and validates payments associated with appointments.  

- **User Table**
  - **Fields**: userId (PK), username, passwordHash, role (patient, doctor, admin).  
  - **Responsibility**: Handles authentication and authorization within the system.  

- **Doctor Table**
  - **Fields**: doctorId (PK), name, specialization, licenseNumber, availability (time slots).  
  - **Responsibility**: Stores professional information and schedules for doctors.  

- **Patient Table**
  - **Fields**: patientId (PK), name, age, gender, contactInfo, insuranceInfo.  
  - **Responsibility**: Stores patients’ personal information for appointments and billing.  


##### NoSQL (Google Firestore)
Used for dynamic, semi-structured, and quickly accessible data.

- **Patient Collection**
  - **Documents**: `{ patientId }`  
  - **Fields**: demographics (age, gender, address), medicalHistory[] (allergies, conditions, surgeries), contactInfo (phone, email).  
  - **Responsibility**: Stores complete medical history for each patient.  

- **Doctor Collection**
  - **Documents**: `{ doctorId }`  
  - **Fields**: specialization, availability[] (time slots), ratings (patient feedback).  
  - **Responsibility**: Real-time management of doctor profiles and availability.  

- **Notification Collection**
  - **Documents**: `{ notificationId }`  
  - **Fields**: patientId, doctorId, type (appointment reminder, payment confirmation), status (sent, pending).  
  - **Responsibility**: Stores and manages reminders and alerts across the system.  



##### Object Storage (Google Cloud Storage)
Used for unstructured and heavy medical files.

- **Folders / Buckets per patient**
  - **Example**: `patients/{patientId}/documents/`  
  - **Content**:  
    - Medical images: X-rays, MRIs, ultrasounds  
    - PDF documents: prescriptions, lab results  
    - Attachments: doctor orders, certificates  
  - **Responsibility**: Ensures secure and scalable storage of medical documents and media.  



##### Analytics (Google BigQuery – optional but recommended)
- **Data processed**: appointment history, payment trends, cancellations, doctor availability.  
- **Usage**: generate reports, detect cancellation patterns, identify high-demand specializations, forecast workload. 

---

### API Specifications

The system exposes a set of RESTful APIs through the **API Gateway (Apigee / Cloud Endpoints)**.  
All endpoints are secured with **OAuth 2.0 / JWT** via **Google Identity Platform**.  
Data exchange is in **JSON** format.


#### **Authentication Service**
- **POST /auth/login**
  - **Description**: Authenticates a user (patient, doctor, or admin).
  - **Request Body**: `{ "username": "string", "password": "string" }`
  - **Response**: `{ "token": "jwt_token", "role": "patient|doctor|admin" }`

- **POST /auth/register**
  - **Description**: Registers a new patient.
  - **Request Body**: `{ "username": "string", "password": "string", "role": "patient", "contactInfo": {...} }`
  - **Response**: `{ "userId": "uuid", "status": "created" }`

---

#### **Patient Service**
- **GET /patients/{patientId}**
  - **Description**: Retrieves patient profile and medical history.
  - **Response**: `{ "patientId": "uuid", "demographics": {...}, "medicalHistory": [...] }`

- **PUT /patients/{patientId}**
  - **Description**: Updates patient information.
  - **Request Body**: `{ "contactInfo": {...}, "insuranceInfo": {...} }`
  - **Response**: `{ "status": "updated" }`

---

#### **Doctor Service**
- **GET /doctors/{doctorId}**
  - **Description**: Retrieves doctor profile and availability.
  - **Response**: `{ "doctorId": "uuid", "specialization": "string", "availability": [...] }`

- **GET /doctors**
  - **Description**: Lists all doctors with filtering (specialization, rating).
  - **Query Params**: `?specialization=cardiology&rating=4`
  - **Response**: `[ { "doctorId": "uuid", "name": "string", "specialization": "string" } ]`

---

#### **Appointment Service**
- **POST /appointments**
  - **Description**: Creates a new appointment.
  - **Request Body**: `{ "patientId": "uuid", "doctorId": "uuid", "date": "YYYY-MM-DD", "time": "HH:mm" }`
  - **Response**: `{ "appointmentId": "uuid", "status": "scheduled" }`

- **GET /appointments/{appointmentId}**
  - **Description**: Retrieves details of a specific appointment.
  - **Response**: `{ "appointmentId": "uuid", "doctorId": "uuid", "date": "YYYY-MM-DD", "status": "scheduled" }`

- **PUT /appointments/{appointmentId}/cancel**
  - **Description**: Cancels an existing appointment.
  - **Response**: `{ "status": "cancelled" }`

---

#### **Payment Service**
- **POST /payments**
  - **Description**: Initiates a payment for an appointment.
  - **Request Body**: `{ "appointmentId": "uuid", "method": "credit_card", "amount": 50.0 }`
  - **Response**: `{ "paymentId": "uuid", "status": "pending" }`

- **GET /payments/{paymentId}**
  - **Description**: Retrieves payment details.
  - **Response**: `{ "paymentId": "uuid", "status": "completed", "transactionRef": "string" }`

---

#### **Notification Service**
- **POST /notifications**
  - **Description**: Sends a notification to a patient or doctor.
  - **Request Body**: `{ "userId": "uuid", "type": "appointment_reminder", "message": "string" }`
  - **Response**: `{ "notificationId": "uuid", "status": "sent" }`

- **GET /notifications/{userId}**
  - **Description**: Retrieves all notifications for a user.
  - **Response**: `[ { "notificationId": "uuid", "type": "string", "status": "sent" } ]`

---

#### **Reporting / Analytics Service**
- **GET /reports/appointments**
  - **Description**: Retrieves aggregated statistics of appointments.
  - **Response**: `{ "total": 200, "completed": 180, "cancelled": 20 }`

- **GET /reports/payments**
  - **Description**: Retrieves payment trends and history.
  - **Response**: `{ "totalRevenue": 15000, "pending": 10, "completed": 190 }`

---

### Functional Flows (User - GUI)



---

## Discussion and Reflection

In this section, the team must provide a critical analysis of the design and implementation carried out
during the project. The goal is not only to describe what was done, but also to reason about why
decisions were made, evaluate the effectiveness of the solution, and assess how well the system
demonstrates cloud-native principles.

The discussion should include the following elements:

 - **Design Rationale**
 - **Implementation Challenges**
 - **Cloud-Native Principles Evaluation**
 - **Effectiveness of the Process**
 - **Lessons Learned**