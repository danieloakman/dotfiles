import Wp from 'gi://AstalWp';
import { createBinding, createComputed } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { clamp } from '../utils/number';
import { debounce } from '../utils/fn';

const wp = Wp.get_default();
const volume = createBinding(wp.audio.defaultSpeaker, 'volume');
const muted = createBinding(wp.audio.defaultSpeaker, 'mute');

export const toggleMute = debounce(() => {
  execAsync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle');
}, 100);

export const setVolume = debounce((value: number) => {
  execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value}`);
}, 100);

export default function Volume() {
  return (
    <box spacing={4} cssClasses={classes('border', 'p-xs', 'rounded-sm')}>
      <button cssClasses={classes('btn-ghost', 'rounded-full')} onClicked={toggleMute}>
        <VolumeIndicator />
      </button>

      <slider
        value={volume}
        hexpand
        min={0}
        max={1}
        step={0.05}
        onChangeValue={({ value }) => {
          setVolume(value);
        }}
      />

      <label label={volume.as((v) => `${clamp(Math.round(v * 100), 0, 100)}%`)} widthChars={3} />
    </box>
    /* <menubutton name="volume" hexpand halign={Gtk.Align.CENTER}>
      <box spacing={4}>
        <VolumeIndicator />
        <label label={volume.as((v) => v.toFixed(2))} widthChars={3} />
      </box>
      <popover hexpand>
        <box orientation={Gtk.Orientation.HORIZONTAL} spacing={4}>
          <With value={muted}>
            {(m) =>
              m != null && (
                <switch
                  height_request={24}
                  active={!m}
                  onNotifyActive={() => execAsync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle')}
                />
              )
            }
          </With>
          <slider
            value={volume}
            width_request={150}
            min={0}
            max={1}
            step={0.05}
            onChangeValue={({ value }) => {
              execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value}`);
            }}
          />
        </box>
      </popover>
    </menubutton> */
  );
}

export function VolumeIndicator() {
  return (
    <Icon
      name={createComputed([muted, volume], (m, v) =>
        m ? 'volume-off' : v < 0.1 ? 'volume' : v < 0.33 ? 'volume-1' : 'volume-2',
      )}
    />
  );
}
