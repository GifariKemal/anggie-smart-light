import { CreateCommandInput, DeviceCommand } from '../domain/types';
import { adminOnlyCommands } from '../dto/validators';
import { forbidden, validationError } from '../http/api-error';
import { InMemoryDeviceRepository } from '../repositories/in-memory-device.repository';

export class DeviceCommandService {
  private commandSequence = 0;

  constructor(
    private readonly repository: InMemoryDeviceRepository,
    private readonly now: () => Date = () => new Date()
  ) {}

  createCommand(
    deviceId: string,
    input: CreateCommandInput,
    correlationId: string,
    role: string | undefined
  ): DeviceCommand {
    this.repository.getDevice(deviceId);

    if (adminOnlyCommands.has(input.type) && role !== 'admin') {
      throw forbidden('Command requires admin role', { type: input.type });
    }

    const issuedAt = this.now();
    const expiresAt = input.expiresAt ? new Date(input.expiresAt) : new Date(issuedAt.getTime() + 30_000);

    if (expiresAt.getTime() <= issuedAt.getTime()) {
      throw validationError('Command expiration must be in the future', { field: 'expiresAt' });
    }

    const command: DeviceCommand = {
      schema: 'device.command.v1',
      commandId: input.commandId ?? this.nextCommandId(),
      deviceId,
      type: input.type,
      payload: input.payload ?? {},
      status: 'queued',
      issuedAt: issuedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
      ackAt: null,
      rejectReason: null,
      correlationId,
    };

    return this.repository.createCommand(command);
  }

  private nextCommandId(): string {
    this.commandSequence += 1;
    return `cmd_${this.commandSequence.toString().padStart(6, '0')}`;
  }
}
