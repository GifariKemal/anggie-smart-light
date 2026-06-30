import express from 'express';
import { DeviceCommandService } from './services/device-command.service';
import { InMemoryDeviceRepository } from './repositories/in-memory-device.repository';
import { errorHandler } from './http/error-handler';
import { requestContext } from './http/request-context';
import { createRoutes } from './http/routes';

export function createApp(options: { now?: () => Date } = {}) {
  const now = options.now ?? (() => new Date());
  const repository = new InMemoryDeviceRepository(now);
  const commandService = new DeviceCommandService(repository, now);
  const app = express();

  app.use(express.json({ limit: '1mb' }));
  app.use(requestContext);
  app.use(createRoutes(repository, commandService));
  app.use(errorHandler);

  return app;
}
