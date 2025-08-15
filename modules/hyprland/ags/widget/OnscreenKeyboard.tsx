import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { createExternal, createState, With } from 'ags';
import { noop } from '../utils/fn';

const [isOnScreenKeyboardVisible, setIsOnScreenKeyboardVisible] = createState(false);

export const hasTouchScreen = createExternal(false, (set) => {
  execAsync('zsh -c "ls /sys/class/input/*/name | xargs cat"')
    .then((res) => set(res.includes('touch')))
    .catch(() => set(false));
  return noop;
});

export const toggleOnScreenKeyboard = () =>
  execAsync(`zsh -c "kill -34 $(ps -C wvkbd-mobintl | awk 'NR>1 {print $1}')"`).then(() =>
    setIsOnScreenKeyboardVisible((v) => !v),
  );

export default function OnscreenKeyboard() {
  const icon = isOnScreenKeyboardVisible.as((v) => (v ? 'keyboard-off' : 'keyboard'));
  return (
    <With value={hasTouchScreen}>
      {(hasTouchScreen) => {
        if (!hasTouchScreen) return null;
        return (
          <button onClicked={toggleOnScreenKeyboard} tooltipText="Toggle on-screen keyboard">
            <Icon name={icon} />
          </button>
        );
      }}
    </With>
  );
}
