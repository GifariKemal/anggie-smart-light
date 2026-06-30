export class ApiError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details: Record<string, unknown> = {}
  ) {
    super(message);
  }
}

export function notFound(message: string, details: Record<string, unknown> = {}): ApiError {
  return new ApiError(404, 'NOT_FOUND', message, details);
}

export function validationError(message: string, details: Record<string, unknown> = {}): ApiError {
  return new ApiError(400, 'VALIDATION_ERROR', message, details);
}

export function conflict(message: string, details: Record<string, unknown> = {}): ApiError {
  return new ApiError(409, 'CONFLICT', message, details);
}

export function forbidden(message: string, details: Record<string, unknown> = {}): ApiError {
  return new ApiError(403, 'FORBIDDEN', message, details);
}
