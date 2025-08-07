import { Accessor, createComputed, createExternal, createState, Setter } from 'ags';

/** Converts a value or accessor to an accessor. So downstream we can just always assume it's an accessor. */
export function toAccessor<T>(value: T | Accessor<T>): Accessor<T> {
  return value instanceof Accessor ? value : new Accessor(() => value);
}

const timestamped = <T>(state: T): { state: T; timestamp: number } => ({ state, timestamp: Date.now() });

/** Acts as a mutable `createExternal` */
export function createExternalState<T extends object | number | string | boolean>(
  initialValue: T,
  setter: (set: Setter<T>) => () => unknown,
) {
  const [value, setValue] = createState<T>(initialValue);
  const valueTs = value.as(timestamped);
  const external = createExternal(value.get(), setter);
  const externalTs = external.as(timestamped);
  const resultValue = createComputed([valueTs, externalTs], (v, e) =>
    v.timestamp > e.timestamp ? v.state : e.state,
  );
  const resultSetter = (newValue: T | ((value: T) => T)): void => {
    setValue(typeof newValue === 'function' ? newValue(value.get()) : newValue);
  };
  return [resultValue, resultSetter] as const;
}
