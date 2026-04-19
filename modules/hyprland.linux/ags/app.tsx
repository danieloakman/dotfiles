import app from 'ags/gtk4/app';
import style from './src/style.scss';
import Bar from './src/widget/Bar';
import ControlCenter from './src/widget/ControlCenter';
import PasswordSearch from './src/widget/PasswordSearch';
import { NativeIconProvider } from './src/components/NativeIcon';
import { toggleWindow, WindowName } from './src/utils/window';
import AppsModal from './src/widget/Apps';
import { loadStyles } from './src/utils/styles';
import { createBinding, Fragment } from 'ags';
import { raise } from '@/js-utils';

const HELP = `
Usage
$ ags <command>

Commands
toggle
  - Toggle a window's visibility
  - Usage: toggle <window_id>
`.trim();

app.start({
  css: style,
  requestHandler: ([cmd, ...args], res) => {
    switch (cmd) {
      case 'toggle':
        const windowId = args[0];
        if (!windowId) {
          res(HELP);
          return;
        }
        toggleWindow(windowId as WindowName);
        res('Success');
        return;
      default:
        console.warn('Unknown command:', cmd);
        res(HELP);
        return;
    }
  },
  main() {
    loadStyles();
    const monitors = createBinding(app, 'monitors').as((m) =>
      m.sort((a, b) => b.get_geometry().width - a.get_geometry().width),
    );
    const primaryMonitor = monitors.as((m) => m[0] ?? raise('No monitors found'));
    return (
      <Fragment>
        {/* Put the Bar on the primary monitor, which is the largest monitor */}
        <Bar monitor={primaryMonitor} />
        <ControlCenter />
        <PasswordSearch />
        <AppsModal />
        <NativeIconProvider />
        {/* <NotificationPopups /> */}
      </Fragment>
    );
  },
});
