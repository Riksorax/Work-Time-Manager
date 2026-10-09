/** Wird geworfen, wenn ein Promise nicht innerhalb der vorgegebenen Zeit abgeschlossen hat. */
export class PromiseTimeoutError extends Error {
  constructor(readonly timeoutMs: number) {
    super(`Zeitüberschreitung nach ${timeoutMs} ms`);
    this.name = 'PromiseTimeoutError';
  }
}

/**
 * Begrenzt das Warten auf `promise` auf `ms` Millisekunden (pure, ohne Angular).
 *
 * Ein per Timeout aufgegebenes Promise ist nicht abbrechbar und kann später noch landen oder scheitern; ein
 * nachträgliches Scheitern wird deshalb still verschluckt (keine unbehandelte Rejection). Der Timer wird immer
 * wieder entfernt.
 */
export function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  // Spätes Scheitern nach dem Timeout darf keine unbehandelte Rejection erzeugen.
  promise.catch(() => undefined);
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new PromiseTimeoutError(ms)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}
