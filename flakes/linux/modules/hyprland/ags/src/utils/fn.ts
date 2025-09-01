import { Timer, timeout } from 'ags/time';

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
