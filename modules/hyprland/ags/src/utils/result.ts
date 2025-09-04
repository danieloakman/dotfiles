// eslint-disable-next-line @typescript-eslint/no-namespace
export declare namespace Result {
  export type Ok<T = object> = { status: 'success'; data: T; error: undefined };
  export type Err<E extends object = object> = { status: 'error'; error: E; data: undefined };
}

export type Result<T = object, E extends Error = Error> = Result.Ok<T> | Result.Err<E>;

interface CreateErr {
  <E extends object>(error: E): Result.Err<E>;
  (...args: ConstructorParameters<typeof Error>): Result.Err<Error>;
}

export const Result = {
  Ok: <T>(data: T) => ({ status: 'success', data }) as Result.Ok<T>,
  Err: ((error: object) => ({ status: 'error', error })) as CreateErr,
  /**
   * @description If the provided result is a success, return the data.
   * If a default value is provided and there's an error, return the default value.
   * @throws {Error} If the provided result is an error.
   */
  unwrap: <T>({ data, error }: Result<T>, defaultValue?: T) => {
    if (error) {
      if (defaultValue !== undefined) return defaultValue;
      throw error;
    }
    return data;
  },
  isOk: <T>(result: Result<T>): result is Result.Ok<T> => result.status === 'success',
  isError: <T, E extends Error>(result: Result<T, E>): result is Result.Err<E> => result.status === 'error',
} as const;

export default Result;
