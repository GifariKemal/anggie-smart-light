import {
  AckPayload,
  CommandStatus,
  DeviceCommand,
  DeviceState,
  DeviceSummary,
  TelemetryPayload,
} from '../domain/types';
import { conflict, notFound } from '../http/api-error';

export class InMemoryDeviceRepository {
  private readonly devices = new Map<string, DeviceSummary>();
  private readonly states = new Map<string, DeviceState>();
  private readonly telemetry = new Map<string, TelemetryPayload[]>();
  private readonly commands = new Map<string, DeviceCommand[]>();

  constructor(private readonly now: () => Date = () => new Date()) {
    this.seed();
  }

  listDevices(): DeviceSummary[] {
    return [...this.devices.values()];
  }

  getDevice(deviceId: string): DeviceSummary {
    const device = this.devices.get(deviceId);
    if (!device) {
      throw notFound('Device not found', { deviceId });
    }

    return device;
  }

  findDeviceByLegacyLocation(location: string): DeviceSummary {
    const normalizedLocation = normalizeLegacyLocation(location);
    const device = [...this.devices.values()].find((row) => {
      return (
        normalizeLegacyLocation(row.id) === normalizedLocation ||
        normalizeLegacyLocation(row.name) === normalizedLocation
      );
    });

    if (!device) {
      throw notFound('Light location not found', { location });
    }

    return device;
  }

  getState(deviceId: string): DeviceState {
    this.getDevice(deviceId);
    const state = this.states.get(deviceId);
    if (!state) {
      throw notFound('Device state not found', { deviceId });
    }

    return state;
  }

  listTelemetry(deviceId: string, limit = 50): TelemetryPayload[] {
    this.getDevice(deviceId);
    return [...(this.telemetry.get(deviceId) ?? [])].slice(-limit).reverse();
  }

  appendTelemetry(payload: TelemetryPayload): TelemetryPayload {
    this.getDevice(payload.deviceId);
    const rows = this.telemetry.get(payload.deviceId) ?? [];
    rows.push(payload);
    this.telemetry.set(payload.deviceId, rows);

    this.updateDevice(payload.deviceId, {
      lastSeenAt: this.now().toISOString(),
      firmwareVersion: payload.firmware ?? this.getDevice(payload.deviceId).firmwareVersion,
      status: payload.safetyState === 'fault' ? 'fault' : 'online',
    });

    const previousState = this.getState(payload.deviceId);
    this.states.set(payload.deviceId, {
      schema: 'device.state.v1',
      deviceId: payload.deviceId,
      seq: payload.seq,
      mode: payload.mode,
      online: true,
      relayOn: payload.relayOn,
      dimmerPct: payload.dimmerPct,
      targetLux: payload.targetLux,
      safetyState: payload.safetyState,
      faultReason: payload.faultReason,
      lastCommandId: previousState.lastCommandId,
      serverReceivedAt: this.now().toISOString(),
    });

    return payload;
  }

  createCommand(command: DeviceCommand): DeviceCommand {
    this.getDevice(command.deviceId);
    const rows = this.commands.get(command.deviceId) ?? [];
    const existing = rows.find((row) => row.commandId === command.commandId);

    if (existing) {
      if (sameCommand(existing, command)) {
        return existing;
      }

      throw conflict('Command id already exists with different payload', {
        deviceId: command.deviceId,
        commandId: command.commandId,
      });
    }

    rows.push(command);
    this.commands.set(command.deviceId, rows);

    const state = this.getState(command.deviceId);
    this.states.set(command.deviceId, {
      ...state,
      lastCommandId: command.commandId,
      serverReceivedAt: this.now().toISOString(),
    });

    return command;
  }

  listCommands(deviceId: string): DeviceCommand[] {
    this.getDevice(deviceId);
    return [...(this.commands.get(deviceId) ?? [])].reverse();
  }

  getCommand(deviceId: string, commandId: string): DeviceCommand {
    this.getDevice(deviceId);
    const command = (this.commands.get(deviceId) ?? []).find((row) => row.commandId === commandId);
    if (!command) {
      throw notFound('Command not found', { deviceId, commandId });
    }

    return command;
  }

  applyAck(ack: AckPayload): DeviceCommand {
    const command = this.getCommand(ack.deviceId, ack.commandId);
    const nextStatus = mapAckStatus(ack.status);
    const updated: DeviceCommand = {
      ...command,
      status: nextStatus,
      ackAt: this.now().toISOString(),
      rejectReason: ack.rejectReason ?? (nextStatus === 'expired' ? 'COMMAND_EXPIRED' : command.rejectReason),
    };

    this.replaceCommand(updated);

    const previousState = this.getState(ack.deviceId);
    this.states.set(ack.deviceId, {
      ...previousState,
      seq: Math.max(previousState.seq, ack.deviceSeq),
      mode: ack.effectiveState?.mode ?? previousState.mode,
      relayOn: ack.effectiveState?.relayOn ?? previousState.relayOn,
      dimmerPct: ack.effectiveState?.dimmerPct ?? previousState.dimmerPct,
      safetyState: ack.effectiveState?.safetyState ?? previousState.safetyState,
      faultReason: ack.effectiveState?.faultReason ?? previousState.faultReason,
      lastCommandId: ack.commandId,
      serverReceivedAt: this.now().toISOString(),
    });

    return updated;
  }

  private replaceCommand(command: DeviceCommand): void {
    const rows = this.commands.get(command.deviceId) ?? [];
    this.commands.set(
      command.deviceId,
      rows.map((row) => (row.commandId === command.commandId ? command : row))
    );
  }

  private updateDevice(deviceId: string, patch: Partial<DeviceSummary>): void {
    const device = this.getDevice(deviceId);
    this.devices.set(deviceId, { ...device, ...patch });
  }

  private seed(): void {
    const now = this.now().toISOString();
    const device: DeviceSummary = {
      id: 'anggie-001',
      siteId: 'site_demo',
      name: 'Anggie Demo Lamp',
      hardwareModel: 'DOIT ESP32 DEVKIT V1',
      firmwareVersion: '0.1.0',
      claimedAt: now,
      lastSeenAt: null,
      status: 'offline',
    };

    this.devices.set(device.id, device);
    this.states.set(device.id, {
      schema: 'device.state.v1',
      deviceId: device.id,
      seq: 0,
      mode: 'auto',
      online: false,
      relayOn: false,
      dimmerPct: 0,
      targetLux: 500,
      safetyState: 'standby',
      faultReason: null,
      lastCommandId: null,
      serverReceivedAt: now,
    });
    this.telemetry.set(device.id, []);
    this.commands.set(device.id, []);
  }
}

function mapAckStatus(status: AckPayload['status']): CommandStatus {
  switch (status) {
    case 'accepted':
    case 'ignored_duplicate':
      return 'acked';
    case 'applied':
      return 'applied';
    case 'rejected':
      return 'rejected';
    case 'expired':
      return 'expired';
    default:
      return 'acked';
  }
}

function sameCommand(left: DeviceCommand, right: DeviceCommand): boolean {
  return (
    left.type === right.type &&
    left.expiresAt === right.expiresAt &&
    JSON.stringify(left.payload) === JSON.stringify(right.payload)
  );
}

function normalizeLegacyLocation(value: string): string {
  return decodeURIComponent(value).trim().toLowerCase();
}
