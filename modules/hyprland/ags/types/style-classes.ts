export const STYLE_CLASSES = [
  "rounded-sm",
  "rounded-md",
  "rounded-lg",
  "rounded-xl",
  "rounded-full",
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