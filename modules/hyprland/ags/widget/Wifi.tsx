import { createConnection, With } from 'ags';
import { execAsync } from 'ags/process';
import Network from 'gi://AstalNetwork';
import { Icon } from '../components/Icon';
import Gtk from 'gi://Gtk';

const network = Network.get_default();

// TODO: need to delay the get_wifi call as when these are notified, the network hasn't quite connected the wifi yet. 
const getWifi = (label: string) => () => {
  // console.log(`getWifi ${label}`)
  return network.get_wifi();
}
const wifi = createConnection(
  network.get_wifi(),
  [network, 'notify::wifi', getWifi('wifi')],
  [network, 'notify::connectivity', getWifi('connectivity')],
  [network, 'notify::primary', getWifi('primary')],
);

const WIFI_STRENGTH: Icon.Name[] = ['wifi-zero', 'wifi-low', 'wifi-high'];
const getWifiStrength = (strength: number) =>
  WIFI_STRENGTH[Math.ceil(strength / 33) - 1] ?? 'wifi-off';

export default function Wifi() {
  return (
    <button name="wifi" onClicked={() => execAsync('nm-connection-editor')}>
      <With value={wifi}>
        {(wifi) => {
          // TODO: Add a better no wifi state
          if (!wifi)
            return (
              <box spacing={4} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                <Icon name="wifi-off" />
              </box>
            );
          // TODO: need to update wifi strength on some interval or on some event
          return (
            <box spacing={4}>
              <Icon name={getWifiStrength(wifi.strength)} marginBottom={8} />
              <label label={wifi.ssid} />
            </box>
          );
        }}
      </With>
    </button>
  );
}
