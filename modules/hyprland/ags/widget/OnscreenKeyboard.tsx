import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { createState } from 'ags';

const [isOnScreenKeyboardVisible, setIsOnScreenKeyboardVisible] = createState(false);

export const toggleOnScreenKeyboard = () =>
  execAsync(`zsh -c "kill -34 $(ps -C wvkbd-mobintl | awk 'NR>1 {print $1}')"`).then(() =>
    setIsOnScreenKeyboardVisible((v) => !v),
  );

export default function OnscreenKeyboard() {
  const icon = isOnScreenKeyboardVisible.as((v) => (v ? 'keyboard-off' : 'keyboard'));
  return (
    <button onClicked={toggleOnScreenKeyboard} tooltipText="Toggle on-screen keyboard">
      <Icon name={icon} />
    </button>
  );
}
