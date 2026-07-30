import { Accessor, createComputed, createExternal, createState, onCleanup, Setter } from 'ags';
import { noop } from '@/js-utils';
import { interval } from 'ags/time';

/** Normalize a value or Accessor to an Accessor. */
export function toAccessor<T>(value: T | Accessor<T>): Accessor<T> {
  return value instanceof Accessor ? value : new Accessor(() => value);
}

export type UnwrapAccessor<T> = T extends Accessor<infer U> ? U : T;

const timestamped = <T>(state: T): { state: T; timestamp: number } => ({
  state,
  timestamp: Date.now(),
});

// TODO: there's a bug with this where the first couple or so value updates are not reflected in the external value.
/** Acts as a mutable `createExternal` */
export function createExternalState<T extends object | number | string | boolean>(
  initialValue: T,
  setter: (set: Setter<T>) => (() => unknown) | void | undefined | null,
) {
  const [value, setValue] = createState<T>(initialValue);
  const valueTs = value.as(timestamped);
  const external = createExternal(value.get(), (set) => setter(set) ?? noop);
  const externalTs = external.as(timestamped);
  const resultValue = createComputed([valueTs, externalTs], (v, e) =>
    v.timestamp > e.timestamp ? v.state : e.state,
  );
  const resultSetter = (newValue: T | ((value: T) => T)): void => {
    setValue(typeof newValue === 'function' ? newValue(value.get()) : newValue);
  };
  return [resultValue, resultSetter] as const;
}

export const createBooleanState = (initialValue: boolean) => {
  const [value, set] = createState(initialValue);
  return [
    value,
    {
      set,
      setTrue: () => set(true),
      setFalse: () => set(false),
      toggle: () => set(!value.get()),
    },
  ] as const;
};

export const createInterval = (intervalMs: number) => {
  return createExternal(0, (set) => {
    const t = interval(intervalMs, () => set((n) => n + 1));
    return () => {
      t.cancel();
      set(0);
    };
  });
};

export const distinctUntilChanged =
  <T>(compare: (prev: T, curr: T) => boolean = (prev, curr) => prev === curr) =>
  (value: Accessor<T>) =>
    createExternal(value.get(), (set) => {
      let prev: T | undefined = undefined;
      return value.subscribe(() => {
        const next = value.get();
        if (prev === undefined || !compare(prev, next)) {
          prev = next;
          set(next);
        }
      });
    });

export function useSubscribe<T>(value: Accessor<T>, callback: (value: T) => void) {
  const unsub = value.subscribe(() => callback(value.get()));
  onCleanup(() => unsub());
}
