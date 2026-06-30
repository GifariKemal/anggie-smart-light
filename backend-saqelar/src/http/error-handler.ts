import { ErrorRequestHandler } from 'express';
import { ApiError } from './api-error';
import { RequestWithId } from './request-context';

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const requestId = (req as RequestWithId).requestId || 'req_unknown';

  if (err instanceof ApiError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        requestId,
      },
    });
    return;
  }

  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
      details: {},
      requestId,
    },
  });
};
