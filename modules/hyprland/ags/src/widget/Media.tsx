import Mpris from 'gi://AstalMpris';
import { createConnection } from 'ags';

const spotify = Mpris.Player.new('spotify');

const title = createConnection(spotify.title, [spotify, 'notify::title', () => spotify.title]);
const playbackStatus = createConnection(spotify.playbackStatus, [
  spotify,
  'notify::playback-status',
  () => spotify.playbackStatus,
]);

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
