export const STYLE_CLASSES = [
  "btn-ghost",
  "rounded-none",
  "rounded-sm",
  "rounded-md",
  "rounded-lg",
  "rounded-xl",
  "rounded-full",
  "rounded-l",
  "rounded-r",
  "rounded-t",
  "rounded-b",
  "p-xs",
  "p-sm",
  "p-md",
  "p-lg",
  "p-xl",
  "px-sm",
  "py-sm",
  "bg-transparent",
  "bg-bg-color",
  "opacity-90"
] as const;

export type StyleClass = (typeof STYLE_CLASSES)[number];