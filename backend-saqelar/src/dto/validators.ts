import {
  AckPayload,
  CommandType,
  CreateCommandInput,
  DeviceMode,
  SafetyState,
  TelemetryPayload,
} from '../domain/types';
import { validationError } from '../http/api-error';

const commandTypes: CommandType[] = [
  'SET_MODE',
  'SET_TARGET_LUX',
  'SET_BRIGHTNESS',
  'SET_PID',
  'SET_SAFETY_LIMITS',
  'RESET_FAULT',
  'CALIBRATE_CURRENT_ZERO',
  'SET_TIME',
  'REBOOT',
];

const modes: DeviceMode[] = ['auto', 'manual', 'off'];
const safetyStates: SafetyState[] = ['ok', 'standby', 'fault'];

export const adminOnlyCommands = new Set<CommandType>([
  'SET_PID',
  'SET_SAFETY_LIMITS',
  'CALIBRATE_CURRENT_ZERO',
  'REBOOT',
]);

export function parseCreateCommandDto(value: unknown): CreateCommandInput {
  const body = objectValue(value, 'body');
  const type = enumValue(body.type, commandTypes, 'type');
  const payload = optionalObject(body.payload, 'payload') ?? {};
  const commandId = optionalString(body.commandId, 'commandId');
  const expiresAt = optionalIsoDate(body.expiresAt, 'expiresAt');

  validateCommandPayload(type, payload);

  return { commandId, type, payload, expiresAt };
}

export function parseTelemetryDto(value: unknown, deviceId: string): TelemetryPayload {
  const body = objectValue(value, 'body');
  const payload = {
    schema: literal(body.schema, 'device.telemetry.v1', 'schema'),
    deviceId: literal(body.deviceId, deviceId, 'deviceId'),
    seq: numberValue(body.seq, 'seq'),
    ts: isoDate(body.ts, 'ts'),
    mode: enumValue(body.mode, modes, 'mode'),
    relayOn: booleanValue(body.relayOn, 'relayOn'),
    safetyState: enumValue(body.safetyState, safetyStates, 'safetyState'),
    faultReason: nullableString(body.faultReason, 'faultReason'),
    lux: numberValue(body.lux, 'lux'),
    targetLux: numberValue(body.targetLux, 'targetLux'),
    ldrRaw: numberValue(body.ldrRaw, 'ldrRaw'),
    currentMa: numberValue(body.currentMa, 'currentMa'),
    powerW: numberValue(body.powerW, 'powerW'),
    dimmerPct: rangedNumber(body.dimmerPct, 'dimmerPct', 0, 100),
    pid: optionalPid(body.pid),
    rssi: optionalNumber(body.rssi, 'rssi'),
    uptimeMs: optionalNumber(body.uptimeMs, 'uptimeMs'),
    firmware: optionalString(body.firmware, 'firmware'),
  };

  return payload;
}

export function parseAckDto(value: unknown, deviceId: string): AckPayload {
  const body = objectValue(value, 'body');
  const ackStatuses = ['accepted', 'applied', 'rejected', 'ignored_duplicate', 'expired'] as const;
  const rejectReasons = [
    'SAFETY_LOCKOUT',
    'INVALID_PAYLOAD',
    'UNSUPPORTED_COMMAND',
    'DEVICE_IN_FAULT',
    'COMMAND_EXPIRED',
    'CALIBRATION_REQUIRED',
  ] as const;
  const effectiveState = optionalObject(body.effectiveState, 'effectiveState');

  if (effectiveState) {
    if ('mode' in effectiveState) enumValue(effectiveState.mode, modes, 'effectiveState.mode');
    if ('relayOn' in effectiveState) booleanValue(effectiveState.relayOn, 'effectiveState.relayOn');
    if ('dimmerPct' in effectiveState) rangedNumber(effectiveState.dimmerPct, 'effectiveState.dimmerPct', 0, 100);
    if ('safetyState' in effectiveState) enumValue(effectiveState.safetyState, safetyStates, 'effectiveState.safetyState');
    if ('faultReason' in effectiveState) nullableString(effectiveState.faultReason, 'effectiveState.faultReason');
  }

  return {
    schema: literal(body.schema, 'device.ack.v1', 'schema'),
    deviceId: literal(body.deviceId, deviceId, 'deviceId'),
    commandId: stringValue(body.commandId, 'commandId'),
    status: enumValue(body.status, [...ackStatuses], 'status'),
    deviceSeq: numberValue(body.deviceSeq, 'deviceSeq'),
    message: optionalString(body.message, 'message'),
    rejectReason: optionalEnum(body.rejectReason, [...rejectReasons], 'rejectReason'),
    effectiveState: effectiveState as AckPayload['effectiveState'],
  };
}

function validateCommandPayload(type: CommandType, payload: Record<string, unknown>): void {
  switch (type) {
    case 'SET_MODE':
      enumValue(payload.mode, modes, 'payload.mode');
      return;
    case 'SET_TARGET_LUX':
      rangedNumber(payload.targetLux, 'payload.targetLux', 0, 2000);
      return;
    case 'SET_BRIGHTNESS':
      rangedNumber(payload.dimmerPct, 'payload.dimmerPct', 0, 100);
      return;
    case 'SET_PID':
      numberValue(payload.kp, 'payload.kp');
      numberValue(payload.ki, 'payload.ki');
      numberValue(payload.kd, 'payload.kd');
      return;
    case 'SET_SAFETY_LIMITS':
      rangedNumber(payload.maxCurrentMa, 'payload.maxCurrentMa', 1, 10000);
      return;
    case 'SET_TIME':
      isoDate(payload.ts, 'payload.ts');
      return;
    case 'RESET_FAULT':
    case 'CALIBRATE_CURRENT_ZERO':
    case 'REBOOT':
      if (Object.keys(payload).length > 0) {
        throw validationError('Payload must be empty for this command', { field: 'payload', type });
      }
      return;
    default:
      assertNever(type);
  }
}

function objectValue(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw validationError('Expected object', { field });
  }

  return value as Record<string, unknown>;
}

function optionalObject(value: unknown, field: string): Record<string, unknown> | undefined {
  if (value === undefined) return undefined;
  return objectValue(value, field);
}

function stringValue(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw validationError('Expected non-empty string', { field });
  }

  return value;
}

function optionalString(value: unknown, field: string): string | undefined {
  if (value === undefined) return undefined;
  return stringValue(value, field);
}

function nullableString(value: unknown, field: string): string | null {
  if (value === null) return null;
  return stringValue(value, field);
}

function numberValue(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw validationError('Expected finite number', { field });
  }

  return value;
}

function optionalNumber(value: unknown, field: string): number | undefined {
  if (value === undefined) return undefined;
  return numberValue(value, field);
}

function rangedNumber(value: unknown, field: string, min: number, max: number): number {
  const number = numberValue(value, field);
  if (number < min || number > max) {
    throw validationError('Number out of range', { field, min, max });
  }

  return number;
}

function booleanValue(value: unknown, field: string): boolean {
  if (typeof value !== 'boolean') {
    throw validationError('Expected boolean', { field });
  }

  return value;
}

function enumValue<T extends string>(value: unknown, allowed: readonly T[], field: string): T {
  if (typeof value !== 'string' || !allowed.includes(value as T)) {
    throw validationError('Unexpected value', { field, allowed });
  }

  return value as T;
}

function optionalEnum<T extends string>(value: unknown, allowed: readonly T[], field: string): T | undefined {
  if (value === undefined) return undefined;
  return enumValue(value, allowed, field);
}

function literal<T extends string>(value: unknown, expected: T, field: string): T {
  if (value !== expected) {
    throw validationError('Unexpected value', { field, expected });
  }

  return expected;
}

function isoDate(value: unknown, field: string): string {
  const text = stringValue(value, field);
  if (Number.isNaN(Date.parse(text))) {
    throw validationError('Expected ISO timestamp', { field });
  }

  return text;
}

function optionalIsoDate(value: unknown, field: string): string | undefined {
  if (value === undefined) return undefined;
  return isoDate(value, field);
}

function optionalPid(value: unknown): TelemetryPayload['pid'] {
  if (value === undefined) return undefined;
  const pid = objectValue(value, 'pid');

  return {
    kp: numberValue(pid.kp, 'pid.kp'),
    ki: numberValue(pid.ki, 'pid.ki'),
    kd: numberValue(pid.kd, 'pid.kd'),
    output: numberValue(pid.output, 'pid.output'),
  };
}

function assertNever(value: never): never {
  throw validationError('Unsupported command type', { value });
}
