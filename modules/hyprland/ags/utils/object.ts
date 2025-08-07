export const safeJSONParse = <T = unknown>(str: string): T | null => {
  try {
    return JSON.parse(str) as T;
  } catch (e) {
    return null;
  }
};