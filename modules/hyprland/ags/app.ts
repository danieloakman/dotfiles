import app from 'ags/gtk4/app';
import style from './style.scss';
import Bar from './widget/Bar';
import ControlCenter from './widget/ControlCenter';
import PasswordSearch from './widget/PasswordSearch';
import { NativeIconProvider } from './components/NativeIcon';
import { toggleWindow, WindowName } from './utils/window';
import AppsModal from './widget/Apps';
import { loadStyles } from './utils/styles';

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
  requestHandler: (req, res) => {
    const [cmd, ...args] = req.split(' ');
    switch (cmd) {
      case 'toggle':
        const windowId = args[0];
        if (!windowId) {
          res(HELP);
          return;
        }
        toggleWindow(windowId as WindowName);
        res(1);
        return;
      default:
        res(HELP);
        return;
    }
  },
  main() {
    loadStyles();
    const monitors = app
      .get_monitors()
      .sort((a, b) => b.get_geometry().width - a.get_geometry().width);
    Bar(monitors[0]!); // Put the Bar on the primary monitor, which is the largest monitor
    ControlCenter();
    PasswordSearch();
    NativeIconProvider();
    AppsModal();
  },
});
