export const once = <T extends (...args: any[]) => any>(fn: T) => {
  let result: ReturnType<T> | undefined;
  return (...args: Parameters<T>) => result ?? (result = fn.apply(fn, args));
};

export const noop = () => { };
