export const once = <T extends (...args: any[]) => any>(fn: T) => {
  let result: ReturnType<T> | undefined;
  return (...args: Parameters<T>) => result ?? (result = fn.apply(fn, args));
};

export const noop = () => {};

export const iife = <T extends () => any>(fn: T): ReturnType<T> => fn();
