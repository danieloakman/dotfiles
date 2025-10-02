export const clamp = (value: number, min: number, max: number) =>
  Math.max(min, Math.min(value, max));

export const INT_REGEX = /\d+/;

export const randInt = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1)) + min;
