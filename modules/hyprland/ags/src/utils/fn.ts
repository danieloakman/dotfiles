import { Timer, timeout } from 'ags/time';
import Result from './result';

/** For implementing simple string -> T maps. This is just a subset of a `Map<string, T>`.  */
export interface SimpleMap<T> {
  get(key: string): Nullish<T>;
  set(key: string, value: T): this;
  delete(key: string): boolean;
  has(key: string): boolean;
}

export interface Fn<Args extends any[] = any[], Return = unknown> {
  (...args: Args): Return;
}

export interface AsyncFn<Args extends any[] = any[], Return = unknown> {
  (...args: Args): Promise<Return>;
}

export interface MonoFn<A, B = A> {
  (a: A): B;
}

/** Contains either T, null or undefined. */
export type Nullish<T> = T | null | undefined;

export function isNullish(value: unknown): value is null | undefined {
  return value == null || value == undefined;
}

export const once = <T extends (...args: any[]) => any>(fn: T) => {
  let result: ReturnType<T> | undefined;
  return (...args: Parameters<T>) => result ?? ((result = fn.apply(fn, args)) as ReturnType<T>);
};

export const noop = () => {};

export const iife = <T extends () => any>(fn: T): ReturnType<T> => fn();

export interface Comparator<T, R extends number | boolean> {
  (a: T, b: T): R;
}

/** Combines any number of comparators into a single comparator. Can be used for sorting or equality. */
export function multiComparator<T, R extends number | boolean>(
  ...comparators: Comparator<T, R>[]
): Comparator<T, R> {
  return (a: T, b: T) => {
    let isBool = false;
    for (const comparator of comparators) {
      const result = comparator(a, b);
      isBool = typeof result === 'boolean';
      if (result) return result;
    }
    return (isBool ? false : 0) as R;
  };
}

export function debounce<T extends (...args: any[]) => any>(fn: T, delay: number) {
  let t: Timer | undefined;
  return (...args: Parameters<T>) => {
    t?.cancel();
    t = timeout(delay, () => fn(...args));
  };
}

export function isObjectLike(value: unknown): value is Record<PropertyKey, unknown> {
  return typeof value === 'object' && value !== null;
}

export function raise(error: Error): never;
export function raise(message: string): never;
export function raise(messageOrError: string | Error): never {
  const e = messageOrError instanceof Error ? messageOrError : new Error(messageOrError);
  console.error(e);
  throw e;
}

export function memoize<T extends (...args: any[]) => any>(fn: T): T {
  const cache = new Map<string, ReturnType<T>>();
  return ((...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    if (cache.has(key)) return cache.get(key);
    const result = fn(...args);
    cache.set(key, result);
    return result;
  }) as T;
}

/** Calls `fn` and returns its result as is, or if it throws an error it will return it as a value. */
export function attempt<T extends (...args: any[]) => never, E extends Error = Error>(
  fn: T,
  ...args: Parameters<T>
): Result.Err<E>;
export function attempt<T extends (...args: any[]) => Promise<unknown>, E extends Error = Error>(
  fn: T,
  ...args: Parameters<T>
): Promise<Result<Awaited<ReturnType<T>>, E>>;
export function attempt<T extends (...args: any[]) => unknown, E extends Error = Error>(
  fn: T,
  ...args: Parameters<T>
): Result<ReturnType<T>, E>;
export function attempt<T, E extends Error = Error>(promise: Promise<T>): Promise<Result<T, E>>;
export function attempt(arg: unknown, ...rest: unknown[]): unknown {
  if (arg instanceof Promise) return arg.then(Result.Ok).catch(Result.Err);
  if (typeof arg === 'function') {
    try {
      const result = arg.call(arg, ...rest);
      if (result instanceof Promise) return result.then(Result.Ok).catch(Result.Err);
      return Result.Ok(result);
    } catch (error) {
      return Result.Err(error as object);
    }
  }
  throw new Error('Cannot convert arg to result');
}

export interface MonoFn<A, B = A> {
  (a: A): B;
}

export function pipe<A, B>(a: A, aFn: MonoFn<A, B>): B;
export function pipe<A, B, C>(a: A, aFn: MonoFn<A, B>, bFn: MonoFn<B, C>): C;
export function pipe<A, B, C, D>(a: A, aFn: MonoFn<A, B>, bFn: MonoFn<B, C>, cFn: MonoFn<C, D>): D;
export function pipe<A, B, C, D, E>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
): E;
export function pipe<A, B, C, D, E, F>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
): F;
export function pipe<A, B, C, D, E, F, G>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
): G;
export function pipe<A, B, C, D, E, F, G, H>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
): H;
export function pipe<A, B, C, D, E, F, G, H, I>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
  hFn: MonoFn<H, I>,
): I;
export function pipe<A, B, C, D, E, F, G, H, I, J>(
  a: A,
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
  hFn: MonoFn<H, I>,
  iFn: MonoFn<I, J>,
): J;
export function pipe(initialValue: unknown, ...funcs: MonoFn<unknown, unknown>[]): unknown;
export function pipe(initialValue: unknown, ...funcs: MonoFn<unknown, unknown>[]): unknown {
  let result = initialValue;
  for (const func of funcs) result = func(result);
  return result;
}

export function flow<A, B>(aFn: MonoFn<A, B>): MonoFn<A, B>;
export function flow<A, B, C>(aFn: MonoFn<A, B>, bFn: MonoFn<B, C>): MonoFn<A, C>;
export function flow<A, B, C, D>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
): MonoFn<A, D>;
export function flow<A, B, C, D, E>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
): MonoFn<A, E>;
export function flow<A, B, C, D, E, F>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
): MonoFn<A, F>;
export function flow<A, B, C, D, E, F, G>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
): MonoFn<A, G>;
export function flow<A, B, C, D, E, F, G, H>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
): MonoFn<A, H>;
export function flow<A, B, C, D, E, F, G, H, I>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
  hFn: MonoFn<H, I>,
): MonoFn<A, I>;
export function flow<A, B, C, D, E, F, G, H, I, J>(
  aFn: MonoFn<A, B>,
  bFn: MonoFn<B, C>,
  cFn: MonoFn<C, D>,
  dFn: MonoFn<D, E>,
  eFn: MonoFn<E, F>,
  fFn: MonoFn<F, G>,
  gFn: MonoFn<G, H>,
  hFn: MonoFn<H, I>,
  iFn: MonoFn<I, J>,
): MonoFn<A, J>;
export function flow(...funcs: MonoFn<unknown, unknown>[]): MonoFn<unknown, unknown>;
export function flow(...funcs: MonoFn<unknown, unknown>[]): MonoFn<unknown, unknown> {
  return (value: unknown) => pipe(value, ...funcs);
}
