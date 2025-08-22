export const once = <T extends (...args: any[]) => any>(fn: T) => {
  let result: ReturnType<T> | undefined;
  return (...args: Parameters<T>) => result ?? (result = fn.apply(fn, args));
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
