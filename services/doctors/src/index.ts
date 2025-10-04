import 'dotenv/config';
import express from 'express';

const app = express();
app.use(express.json());

app.get('/healthz', (_req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 4006;
app.listen(PORT, () => console.log(`Doctors service on :${PORT}`));
