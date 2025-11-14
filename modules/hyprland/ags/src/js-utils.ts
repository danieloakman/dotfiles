export * from '@danoaky/js-utils/BinarySearch';
export * from '@danoaky/js-utils/caching';
export * from '@danoaky/js-utils/disposables';
export * from '@danoaky/js-utils/number';
export * from '@danoaky/js-utils/object';
export * from '@danoaky/js-utils/string';
export * from '@danoaky/js-utils/types';
export * from '@danoaky/js-utils/vector2';
export * from '@danoaky/js-utils/result';
export * from '@danoaky/js-utils/misc';
export * from '@danoaky/js-utils/assertions';
export * from '@danoaky/js-utils/functional';

import { raise as _raise } from '@danoaky/js-utils/functional';

export function raise(...args: Parameters<typeof _raise>): never {
  try {
    _raise(...args);
  } catch (e) {
    console.error(e);
    throw e;
  }
}
