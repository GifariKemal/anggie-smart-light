export type DeviceMode = 'auto' | 'manual' | 'off';
export type SafetyState = 'ok' | 'standby' | 'fault';
export type DeviceStatus = 'online' | 'offline' | 'stale' | 'fault';

export type CommandType =
  | 'SET_MODE'
  | 'SET_TARGET_LUX'
  | 'SET_BRIGHTNESS'
  | 'SET_PID'
  | 'SET_SAFETY_LIMITS'
  | 'RESET_FAULT'
  | 'CALIBRATE_CURRENT_ZERO'
  | 'SET_TIME'
  | 'REBOOT';

export type CommandStatus =
  | 'queued'
  | 'published'
  | 'acked'
  | 'applied'
  | 'rejected'
  | 'timeout'
  | 'expired';

export type AckStatus =
  | 'accepted'
  | 'applied'
  | 'rejected'
  | 'ignored_duplicate'
  | 'expired';

export type RejectReason =
  | 'SAFETY_LOCKOUT'
  | 'INVALID_PAYLOAD'
  | 'UNSUPPORTED_COMMAND'
  | 'DEVICE_IN_FAULT'
  | 'COMMAND_EXPIRED'
  | 'CALIBRATION_REQUIRED';

export interface DeviceSummary {
  id: string;
  siteId: string;
  name: string;
  hardwareModel: string;
  firmwareVersion: string;
  claimedAt: string;
  lastSeenAt: string | null;
  status: DeviceStatus;
}

export interface DeviceState {
  schema: 'device.state.v1';
  deviceId: string;
  seq: number;
  mode: DeviceMode;
  online: boolean;
  relayOn: boolean;
  dimmerPct: number;
  targetLux: number;
  safetyState: SafetyState;
  faultReason: string | null;
  lastCommandId: string | null;
  serverReceivedAt: string;
}

export interface TelemetryPayload {
  schema: 'device.telemetry.v1';
  deviceId: string;
  seq: number;
  ts: string;
  mode: DeviceMode;
  relayOn: boolean;
  safetyState: SafetyState;
  faultReason: string | null;
  lux: number;
  targetLux: number;
  ldrRaw: number;
  currentMa: number;
  powerW: number;
  dimmerPct: number;
  pid?: {
    kp: number;
    ki: number;
    kd: number;
    output: number;
  };
  rssi?: number;
  uptimeMs?: number;
  firmware?: string;
}

export interface DeviceCommand {
  schema: 'device.command.v1';
  commandId: string;
  deviceId: string;
  type: CommandType;
  payload: Record<string, unknown>;
  status: CommandStatus;
  issuedAt: string;
  expiresAt: string;
  ackAt: string | null;
  rejectReason: RejectReason | null;
  correlationId: string;
}

export interface AckPayload {
  schema: 'device.ack.v1';
  deviceId: string;
  commandId: string;
  status: AckStatus;
  deviceSeq: number;
  message?: string;
  rejectReason?: RejectReason;
  effectiveState?: Partial<Pick<DeviceState, 'mode' | 'relayOn' | 'dimmerPct' | 'safetyState' | 'faultReason'>>;
}

export interface CreateCommandInput {
  commandId?: string;
  type: CommandType;
  payload?: Record<string, unknown>;
  expiresAt?: string;
}
