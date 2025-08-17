import app from 'ags/gtk4/app';
import style from './style.scss';
import Bar from './widget/Bar';
import ControlCenter from './widget/ControlCenter';
import PasswordSearch from './widget/PasswordSearch';
import { NativeIconProvider } from './components/NativeIcon';

app.start({
  css: style,
  requestHandler: (req, res) => {
    console.log(req);
    res('todo');
  },
  main() {
    app.get_monitors().map(Bar);
    app.get_monitors().map(ControlCenter);
    PasswordSearch();
    NativeIconProvider();
  },
});
