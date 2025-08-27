import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { createExternal, createState } from 'ags';
import { noop } from '../utils/fn';
import { hasTouchDevice } from '../utils/hyprland';

const [isOnScreenKeyboardVisible, setIsOnScreenKeyboardVisible] = createState(false);

export const toggleOnScreenKeyboard = () =>
  execAsync(`zsh -c "kill -34 $(ps -C wvkbd-mobintl | awk 'NR>1 {print $1}')"`).then(() =>
    setIsOnScreenKeyboardVisible((v) => !v),
  );

export default function OnscreenKeyboard() {
  const icon = isOnScreenKeyboardVisible.as((v) => (v ? 'keyboard-off' : 'keyboard'));
  const visible = createExternal(false, (set) => {
    hasTouchDevice().then(set);
    return noop;
  });

  return (
    <box visible={visible}>
      <button onClicked={toggleOnScreenKeyboard} tooltipText="Toggle on-screen keyboard">
        <Icon name={icon} />
      </button>
    </box>
  );
}
