import { Router } from 'express';
import { parseAckDto, parseCreateCommandDto, parseTelemetryDto } from '../dto/validators';
import { DeviceCommandService } from '../services/device-command.service';
import { InMemoryDeviceRepository } from '../repositories/in-memory-device.repository';
import { RequestWithId } from './request-context';
import { openApiDocument } from './openapi';
import { loginHandler, registerHandler } from './auth';

export function createRoutes(repository: InMemoryDeviceRepository, commandService: DeviceCommandService): Router {
  const router = Router();

  router.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'backend-saqelar' });
  });

  router.post('/auth/register', registerHandler);
  router.post('/auth/login', loginHandler);

  router.get('/openapi.json', (_req, res) => {
    res.json(openApiDocument);
  });

  router.get('/devices', (_req, res) => {
    res.json({ data: repository.listDevices() });
  });

  router.get('/lights', (_req, res) => {
    const lights = repository.listDevices().map((device) => {
      const state = repository.getState(device.id);
      const latest = repository.listTelemetry(device.id, 1)[0];

      return {
        id: device.id,
        location: device.name,
        status: state.mode === 'off' || !state.relayOn ? 'OFF' : 'ON',
        deviceId: device.id,
        lux: latest?.lux ?? null,
        targetLux: latest?.targetLux ?? state.targetLux ?? null,
        dimmerPct: latest?.dimmerPct ?? state.dimmerPct ?? null,
        currentMa: latest?.currentMa ?? null,
        powerW: latest?.powerW ?? null,
        safetyState: state.safetyState ?? 'ok',
        faultReason: state.faultReason ?? null,
        lastSeen: device.lastSeenAt ?? state.serverReceivedAt ?? null,
      };
    });

    res.json(lights);
  });

  router.put('/lights/:location', (req, res) => {
    const location = req.params.location;
    const device = repository.findDeviceByLegacyLocation(location);
    const status = String(req.body?.status ?? '').toUpperCase();
    const requestId = (req as unknown as RequestWithId).requestId;

    const command = commandService.createCommand(
      device.id,
      {
        type: 'SET_MODE',
        payload: { mode: status === 'ON' ? 'auto' : 'off' },
      },
      requestId,
      req.header('x-user-role')
    );

    res.json({
      message: `Status lampu di ${device.name} queued as ${status === 'ON' ? 'ON' : 'OFF'}`,
      command,
    });
  });

  router.get('/devices/:deviceId', (req, res) => {
    res.json({ data: repository.getDevice(req.params.deviceId) });
  });

  router.get('/devices/:deviceId/state', (req, res) => {
    res.json({ data: repository.getState(req.params.deviceId) });
  });

  router.get('/devices/:deviceId/telemetry', (req, res) => {
    const limit = Number.parseInt(String(req.query.limit ?? '50'), 10);
    const normalizedLimit = Number.isFinite(limit) && limit > 0 ? Math.min(limit, 500) : 50;
    res.json({ data: repository.listTelemetry(req.params.deviceId, normalizedLimit) });
  });

  router.post('/devices/:deviceId/commands', (req, res) => {
    const dto = parseCreateCommandDto(req.body);
    const requestId = (req as unknown as RequestWithId).requestId;
    const command = commandService.createCommand(req.params.deviceId, dto, requestId, req.header('x-user-role'));
    res.status(201).json({ data: command });
  });

  router.get('/devices/:deviceId/commands', (req, res) => {
    res.json({ data: repository.listCommands(req.params.deviceId) });
  });

  router.get('/devices/:deviceId/commands/:commandId', (req, res) => {
    res.json({ data: repository.getCommand(req.params.deviceId, req.params.commandId) });
  });

  router.post('/internal/devices/:deviceId/telemetry', (req, res) => {
    const dto = parseTelemetryDto(req.body, req.params.deviceId);
    res.status(202).json({ data: repository.appendTelemetry(dto) });
  });

  router.post('/internal/devices/:deviceId/ack', (req, res) => {
    const dto = parseAckDto(req.body, req.params.deviceId);
    res.status(202).json({ data: repository.applyAck(dto) });
  });

  return router;
}
