import { NextFunction, Request, Response } from 'express';

let requestCounter = 0;

export interface RequestWithId extends Request {
  requestId: string;
}

export function requestContext(req: Request, res: Response, next: NextFunction): void {
  const providedRequestId = req.header('x-request-id');
  requestCounter += 1;
  const requestId = providedRequestId || `req_${requestCounter.toString().padStart(6, '0')}`;

  (req as RequestWithId).requestId = requestId;
  res.setHeader('x-request-id', requestId);
  next();
}
