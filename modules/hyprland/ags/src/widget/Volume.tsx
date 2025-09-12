import Wp from 'gi://AstalWp';
import { createBinding, createComputed, For } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { clamp } from '../utils/number';
import { debounce } from '../utils/fn';
import { Gtk } from 'ags/gtk4';
import { createBooleanState } from '@/utils/ags';

const wp = Wp.get_default();
const defaultSpeaker = createBinding(wp.get_audio(), 'defaultSpeaker');
const volume = createBinding(wp.get_audio().get_default_speaker(), 'volume');
const volumeLabel = volume((v) => `${clamp(Math.round(v * 100), 0, 100)}%`);
const muted = createBinding(wp.get_audio().get_default_speaker(), 'mute');
const speakers = createBinding(wp.get_audio(), 'speakers').as((arr) =>
  arr.sort((a, b) =>
    (a.get_device()?.get_description() ?? '').localeCompare(
      b.get_device()?.get_description() ?? '',
    ),
  ),
);

export const toggleMute = debounce(() => {
  execAsync('swayosd-client --output-volume mute-toggle').catch((err) =>
    console.error('mute error', err),
  );
  // execAsync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle');
}, 100);

export const setVolume = debounce((value: number) => {
  const diff = Math.round((value - volume.get()) * 100);
  execAsync(`swayosd-client --output-volume ${diff}`).catch((err) =>
    console.error('volume set error', err),
  );
  // execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value}`);
}, 100);

export default function Volume() {
  const [open, { toggle: toggleOpen }] = createBooleanState(false);

  return (
    <box
      name="Volume"
      spacing={4}
      cssClasses={classes('border', 'p-sm', 'rounded')}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <box spacing={4} valign={Gtk.Align.CENTER}>
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

        <label label={volumeLabel} widthChars={3} />

        <button onClicked={toggleOpen} cssClasses={classes('btn-ghost', 'rounded-full')}>
          <Icon name={open((v) => (v ? 'chevron-down' : 'chevron-right'))} />
        </button>
      </box>

      <revealer revealChild={open}>
        <box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
          <For each={speakers}>
            {(speaker) => {
              const isDefault = createBinding(speaker, 'is_default').as((v) => !!v);
              const device = createBinding(speaker, 'device');
              return (
                <button
                  onClicked={() => speaker.set_is_default(true)}
                  cssClasses={classes('btn-ghost')}
                  widthRequest={100}
                >
                  <box spacing={4}>
                    <Icon name={isDefault((v) => (v ? 'check' : 'dot'))} />
                    <label label={device((v) => v?.get_description() ?? '')} />
                  </box>
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
      tooltipText={volumeLabel}
      name={createComputed([muted, volume], (m, v) =>
        m ? 'volume-off' : v < 0.1 ? 'volume' : v < 0.33 ? 'volume-1' : 'volume-2',
      )}
    />
  );
}
