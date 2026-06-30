import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app';

const fixedNow = new Date('2026-06-30T01:00:00.000Z');

async function run(): Promise<void> {
  const app = createApp({ now: () => fixedNow });

  await request(app)
    .get('/health')
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body.status, 'ok');
    });

  await request(app)
    .get('/devices')
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body.data[0].id, 'anggie-001');
      assert.equal(body.data[0].status, 'offline');
    });

  await request(app)
    .post('/devices/anggie-001/commands')
    .set('x-request-id', 'req_test_command')
    .send({
      commandId: 'cmd_test_001',
      type: 'SET_MODE',
      payload: { mode: 'auto' },
    })
    .expect(201)
    .expect(({ body }) => {
      assert.equal(body.data.schema, 'device.command.v1');
      assert.equal(body.data.status, 'queued');
      assert.equal(body.data.correlationId, 'req_test_command');
      assert.equal(body.data.expiresAt, '2026-06-30T01:00:30.000Z');
    });

  await request(app)
    .post('/internal/devices/anggie-001/ack')
    .send({
      schema: 'device.ack.v1',
      deviceId: 'anggie-001',
      commandId: 'cmd_test_001',
      status: 'applied',
      deviceSeq: 18425,
      message: 'Mode set to auto',
      effectiveState: {
        mode: 'auto',
        relayOn: true,
        dimmerPct: 42,
        safetyState: 'ok',
      },
    })
    .expect(202)
    .expect(({ body }) => {
      assert.equal(body.data.status, 'applied');
      assert.equal(body.data.ackAt, '2026-06-30T01:00:00.000Z');
    });

  await request(app)
    .get('/devices/anggie-001/state')
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body.data.lastCommandId, 'cmd_test_001');
      assert.equal(body.data.relayOn, true);
      assert.equal(body.data.dimmerPct, 42);
      assert.equal(body.data.safetyState, 'ok');
    });

  await request(app)
    .post('/internal/devices/anggie-001/telemetry')
    .send({
      schema: 'device.telemetry.v1',
      deviceId: 'anggie-001',
      seq: 18426,
      ts: '2026-06-30T08:00:00+07:00',
      mode: 'auto',
      relayOn: true,
      safetyState: 'ok',
      faultReason: null,
      lux: 482.5,
      targetLux: 500,
      ldrRaw: 1800,
      currentMa: 320.4,
      powerW: 70.5,
      dimmerPct: 42,
      pid: {
        kp: 0.15,
        ki: 0.05,
        kd: 0.01,
        output: 12.4,
      },
      rssi: -61,
      uptimeMs: 123456,
      firmware: '0.1.0',
    })
    .expect(202);

  await request(app)
    .get('/devices/anggie-001/telemetry')
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body.data.length, 1);
      assert.equal(body.data[0].schema, 'device.telemetry.v1');
      assert.equal(body.data[0].lux, 482.5);
    });

  await request(app)
    .get('/lights')
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body[0].location, 'Anggie Demo Lamp');
      assert.equal(body[0].deviceId, 'anggie-001');
    });

  await request(app)
    .put('/lights/Anggie%20Demo%20Lamp')
    .send({ status: 'OFF' })
    .expect(200)
    .expect(({ body }) => {
      assert.equal(body.command.type, 'SET_MODE');
      assert.equal(body.command.payload.mode, 'off');
      assert.equal(body.command.status, 'queued');
    });

  await request(app)
    .post('/devices/anggie-001/commands')
    .send({
      type: 'SET_BRIGHTNESS',
      payload: { dimmerPct: 101 },
    })
    .expect(400)
    .expect(({ body }) => {
      assert.equal(body.error.code, 'VALIDATION_ERROR');
      assert.equal(body.error.details.field, 'payload.dimmerPct');
      assert.match(body.error.requestId, /^req_/);
    });

  await request(app)
    .post('/devices/anggie-001/commands')
    .send({
      type: 'REBOOT',
      payload: {},
    })
    .expect(403)
    .expect(({ body }) => {
      assert.equal(body.error.code, 'FORBIDDEN');
    });

  await request(app)
    .post('/devices/anggie-001/commands')
    .set('x-user-role', 'admin')
    .send({
      type: 'REBOOT',
      payload: {},
    })
    .expect(201);
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
