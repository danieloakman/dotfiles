const QUIET = process.env.CURSOR_PROXY_QUIET === "true";

export function proxyLog(...args: unknown[]): void {
  if (!QUIET) console.error("[cursor-proxy]", ...args);
}

export function proxyError(...args: unknown[]): void {
  console.error("[cursor-proxy]", ...args);
}
