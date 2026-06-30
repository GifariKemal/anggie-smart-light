export const openApiDocument = {
  openapi: '3.0.3',
  info: {
    title: 'Saqelar Backend Scaffold API',
    version: '0.1.0',
  },
  paths: {
    '/health': {
      get: {
        responses: {
          '200': { description: 'Service health' },
        },
      },
    },
    '/devices': {
      get: {
        responses: {
          '200': { description: 'Visible devices' },
        },
      },
    },
    '/lights': {
      get: {
        summary: 'Legacy lights facade mapped from device state',
        responses: {
          '200': { description: 'Legacy light list' },
        },
      },
    },
    '/lights/{location}': {
      put: {
        summary: 'Legacy light status update facade that queues a device command',
        parameters: [{ name: 'location', in: 'path', required: true, schema: { type: 'string' } }],
        responses: {
          '200': { description: 'Command accepted and queued by backend' },
          '404': { description: 'Not found error envelope' },
        },
      },
    },
    '/devices/{deviceId}/commands': {
      post: {
        summary: 'Issue a device command',
        parameters: [{ name: 'deviceId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: {
          '201': { description: 'Command accepted and queued by backend' },
          '400': { description: 'Validation error envelope' },
          '403': { description: 'Forbidden error envelope' },
          '404': { description: 'Not found error envelope' },
        },
      },
      get: {
        summary: 'List command history',
        parameters: [{ name: 'deviceId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: {
          '200': { description: 'Command history' },
        },
      },
    },
    '/devices/{deviceId}/commands/{commandId}': {
      get: {
        summary: 'Get command status',
        parameters: [
          { name: 'deviceId', in: 'path', required: true, schema: { type: 'string' } },
          { name: 'commandId', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Command status' },
          '404': { description: 'Not found error envelope' },
        },
      },
    },
  },
};
