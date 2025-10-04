import 'dotenv/config';
import express from 'express';

const app = express();
app.use(express.json());

app.get('/healthz', (_req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 4005;
app.listen(PORT, () => console.log(`Patients service on :${PORT}`));
