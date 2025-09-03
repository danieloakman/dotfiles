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
