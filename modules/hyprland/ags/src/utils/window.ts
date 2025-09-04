import app from 'ags/gtk4/app';

export const WINDOW_NAME = {
  Bar: 'bar',
  ControlCenter: 'control-center',
  PasswordSearch: 'password-search',
  Apps: 'apps',
  Notifications: 'notifications',
} as const;

export type WindowName = (typeof WINDOW_NAME)[keyof typeof WINDOW_NAME];

export function hideWindow(windowName: WindowName) {
  app.get_window(windowName)?.hide();
}

export function showWindow(windowName: WindowName) {
  app.get_window(windowName)?.show();
}

export function isWindowVisible(windowName: WindowName) {
  return app.get_window(windowName)?.is_visible();
}

export function toggleWindow(windowName: WindowName) {
  const window = app.get_window(windowName);
  if (!window) {
    console.error(`Window ${windowName} not found`);
    return;
  }

  if (window.is_visible()) window.hide();
  else window.show();
}

export function hideAllWindows() {
  app.get_windows().forEach((window) => {
    if (window.name !== WINDOW_NAME.Bar && window.is_visible()) window.hide();
  });
}
