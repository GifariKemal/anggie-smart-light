import { createHmac } from 'crypto';
import { Request, Response } from 'express';

// ponytail: in-memory auth for local E2E only — no DB, no bcrypt. Swap for real
// user store + password hashing before this ever leaves a dev machine.
const SECRET = 'saqelar-local-dev-secret';

interface User {
  id: string;
  name: string;
  email: string;
  password: string;
}

const users = new Map<string, User>();

// Seeded test operator so login works without registering first.
users.set('operator@saqelar.io', {
  id: 'user-operator',
  name: 'Operator Demo',
  email: 'operator@saqelar.io',
  password: 'operator123',
});

function b64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function signToken(user: User): string {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const payload = b64url(
    JSON.stringify({
      id: user.id,
      name: user.name,
      email: user.email,
      iat: now,
      exp: now + 60 * 60 * 24 * 7,
    })
  );
  const signature = b64url(createHmac('sha256', SECRET).update(`${header}.${payload}`).digest());
  return `${header}.${payload}.${signature}`;
}

const emailShape = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function registerHandler(req: Request, res: Response): void {
  const name = String(req.body?.name ?? '').trim();
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  const confirmPassword = String(req.body?.confirmPassword ?? '');

  if (name.length < 2) {
    res.status(400).json({ message: 'Nama minimal 2 karakter' });
    return;
  }
  if (!emailShape.test(email)) {
    res.status(400).json({ message: 'Format email tidak valid' });
    return;
  }
  if (password.length < 8) {
    res.status(400).json({ message: 'Password minimal 8 karakter' });
    return;
  }
  if (password !== confirmPassword) {
    res.status(400).json({ message: 'Konfirmasi password tidak sama' });
    return;
  }
  if (users.has(email)) {
    res.status(409).json({ message: 'Email sudah terdaftar' });
    return;
  }

  users.set(email, { id: `user-${users.size + 1}`, name, email, password });
  res.status(201).json({ message: 'Registrasi berhasil' });
}

export function loginHandler(req: Request, res: Response): void {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');
  const user = users.get(email);

  if (!user || user.password !== password) {
    res.status(401).json({ message: 'Email atau password salah' });
    return;
  }

  res.status(200).json({ token: signToken(user), name: user.name });
}
