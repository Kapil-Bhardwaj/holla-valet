import type { NextFunction, Request, RequestHandler, Response } from "express";

// Express 4 doesn't catch rejected promises from async route handlers -
// an error thrown inside one becomes an unhandled promise rejection, which
// crashes the whole Node process by default (this is exactly what happened
// with a missing JWT_SECRET: one bad login request took the entire server
// down). Wrapping every async handler in this routes the error to Express's
// error middleware instead, so one bad request returns a 500, not an outage.
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>
): RequestHandler {
  return (req, res, next) => {
    fn(req, res, next).catch(next);
  };
}
