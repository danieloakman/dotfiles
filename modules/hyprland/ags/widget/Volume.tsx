import Wp from 'gi://AstalWp';
import { createBinding, createComputed, createState, For } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { clamp } from '../utils/number';
import { debounce } from '../utils/fn';
import { Gtk } from 'ags/gtk4';

const wp = Wp.get_default();
const defaultSpeaker = createBinding(wp.audio, 'defaultSpeaker');
const volume = createBinding(wp.audio.defaultSpeaker, 'volume');
const muted = createBinding(wp.audio.defaultSpeaker, 'mute');
const speakers = createBinding(wp.audio, 'speakers');

export const toggleMute = debounce(() => {
  execAsync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle');
}, 100);

export const setVolume = debounce((value: number) => {
  execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value}`);
}, 100);

export default function Volume() {
  const [open, setOpen] = createState(false);

  return (
    <box
      spacing={4}
      cssClasses={classes('border', 'p-xs', 'rounded-sm')}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <box spacing={4}>
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

        <button
          onClicked={() => setOpen((v) => !v)}
          cssClasses={classes('btn-ghost', 'rounded-full')}
        >
          <Icon name={open((v) => (v ? 'chevron-down' : 'chevron-right'))} />
        </button>
      </box>

      <revealer revealChild={open}>
        <box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
          <For each={speakers}>
            {(speaker) => {
              const isDefault = createBinding(speaker, 'is_default').as((v) => !!v);
              console.log(isDefault.get());
              return (
                <button onClicked={() => speaker.set_is_default(true)} cssClasses={classes('btn-ghost')}>
                  <centerbox>
                    <label $type="start" label={speaker.device.description} />
                    <Icon $type="end" visible={isDefault} name="check" />
                  </centerbox>
                </button>
              );
            }}
          </For>
        </box>
      </revealer>
    </box>
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
