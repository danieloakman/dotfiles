import Mpris from 'gi://AstalMpris';
import { createBinding } from 'ags';

const spotify = Mpris.Player.new('spotify');

const title = createBinding(spotify, 'title');
const playbackStatus = createBinding(spotify, 'playback_status');

export default function Media() {
  return (
    <box>
      <button onClicked={() => spotify.previous()} label={'<'} />
      <button
        onClicked={() => spotify.play_pause()}
        label={playbackStatus.as((s) => (s === Mpris.PlaybackStatus.PLAYING ? '⏸️' : '▶️'))}
      />
      <button onClicked={() => spotify.next()} label={'>'} />
      <label label={title} />
    </box>
  );
}
