import { createBinding } from 'ags';
import Tray from 'gi://AstalTray';
const tray = Tray.get_default();

export const trayItems = createBinding(tray, 'items');

console.log(trayItems.get());