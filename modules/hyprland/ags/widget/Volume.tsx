import { Gtk } from 'ags/gtk4';

import Wp from 'gi://AstalWp';
import { createComputed, createConnection, With } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';

const wp = Wp.get_default();
const volume = createConnection(wp.audio.default_speaker.volume ?? 0, [
  wp.audio.default_speaker,
  'notify::volume',
  () => wp.audio.default_speaker?.volume ?? 0,
]);
const muted = createConnection(wp.audio.default_speaker.mute ?? true, [
  wp.audio.default_speaker,
  'notify::mute',
  () => wp.audio.default_speaker?.mute ?? true,
]);

export default function Volume() {
  return (
    <menubutton name="volume" hexpand halign={Gtk.Align.CENTER}>
      <box spacing={4}>
        <Icon
          name={createComputed([muted, volume], (m, v) =>
            m ? 'volume-off' : v < 0.33 ? 'volume' : v < 0.66 ? 'volume-1' : 'volume-2',
          )}
        />
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
    </menubutton>
  );
}
