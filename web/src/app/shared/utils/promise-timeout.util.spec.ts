import { PromiseTimeoutError, withTimeout } from './promise-timeout.util';

function deferred<T = void>(): { promise: Promise<T>; resolve: (v: T) => void; reject: (e: unknown) => void } {
  let resolve!: (v: T) => void;
  let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

describe('withTimeout', () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => {
    const timers = vi.getTimerCount();
    vi.useRealTimers();
    expect(timers).toBe(0);
  });

  it('liefert den Wert, wenn das Promise vor Ablauf erfüllt wird, und entfernt den Timer', async () => {
    const d = deferred<number>();
    const result = withTimeout(d.promise, 30_000);
    expect(vi.getTimerCount()).toBe(1);
    d.resolve(42);
    await expect(result).resolves.toBe(42);
    expect(vi.getTimerCount()).toBe(0);
  });

  it('reicht den Fehler des Originals durch und entfernt den Timer', async () => {
    const d = deferred<number>();
    const boom = new Error('boom');
    const result = withTimeout(d.promise, 30_000);
    const assertion = expect(result).rejects.toBe(boom);
    d.reject(boom);
    await assertion;
    expect(vi.getTimerCount()).toBe(0);
  });

  it('rejected nach exakt ms mit PromiseTimeoutError (29_999 noch offen)', async () => {
    const d = deferred<number>();
    let state: 'pending' | 'rejected' | 'resolved' = 'pending';
    let error: unknown;
    withTimeout(d.promise, 30_000).then(
      () => { state = 'resolved'; },
      e => { state = 'rejected'; error = e; },
    );
    await vi.advanceTimersByTimeAsync(29_999);
    expect(state).toBe('pending');
    await vi.advanceTimersByTimeAsync(1);
    expect(state).toBe('rejected');
    expect(error).toBeInstanceOf(PromiseTimeoutError);
    expect((error as PromiseTimeoutError).name).toBe('PromiseTimeoutError');
    expect(vi.getTimerCount()).toBe(0);
    d.resolve(1); // spätes Landen bleibt folgenlos
    await vi.advanceTimersByTimeAsync(0);
  });

  it('ein nach dem Timeout spät rejectendes Original erzeugt keine unbehandelte Rejection', async () => {
    // Ein Rejection-Handler am Original ist die Voraussetzung dafür; erzeugte eine späte Rejection trotzdem eine
    // unbehandelte, meldete Vitest sie als Fehler des Laufs.
    const d = deferred<number>();
    const catchSpy = vi.spyOn(d.promise, 'catch');
    const result = withTimeout(d.promise, 1_000);
    expect(catchSpy).toHaveBeenCalledTimes(1);
    const assertion = expect(result).rejects.toBeInstanceOf(PromiseTimeoutError);
    await vi.advanceTimersByTimeAsync(1_000);
    await assertion;
    d.reject(new Error('spät'));
    await vi.advanceTimersByTimeAsync(0);
    expect(vi.getTimerCount()).toBe(0);
  });
});
