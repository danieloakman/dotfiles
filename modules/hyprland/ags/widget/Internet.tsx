import { createBinding, createComputed, createConnection, With } from 'ags';
import { execAsync } from 'ags/process';
import Network from 'gi://AstalNetwork';
import { Icon } from '../components/Icon';
import { UnwrapAccessor } from '../utils/ags';

const network = Network.get_default();

export const wifi = createBinding(network, 'wifi');
export const client = createBinding(network, 'client');

export type NetworkClient = UnwrapAccessor<typeof client>;
export type PrimaryConnection = ReturnType<UnwrapAccessor<NetworkClient['get_primary_connection']>>;

/** The primary internet connection. Can be wired or wireless or none. */
const getPrimaryConnection = (): PrimaryConnection | null =>
  network.get_client().get_primary_connection();
export const primaryConnection = createConnection(
  getPrimaryConnection(),
  [network, 'notify::primary', getPrimaryConnection],
  [network, 'notify::wifi', getPrimaryConnection],
  [network, 'notify::connectivity', getPrimaryConnection],
);

export const primaryConnectionType = primaryConnection((c) =>
  !c ? null : c?.type.includes('wireless') ? 'wifi' : 'wired',
);

const WIFI_STRENGTH: Icon.Name[] = ['wifi-zero', 'wifi-low', 'wifi-high'];
const getWifiStrength = (strength: number) =>
  WIFI_STRENGTH[Math.ceil(strength / 33) - 1] ?? 'wifi-off';

const data = createComputed([primaryConnection, wifi], (c, wifi) => ({
  primaryConnection: c,
  wifi,
}));

export default function Internet() {
  return (
    <button name="internet" onClicked={() => execAsync('nm-connection-editor')}>
      <With value={data}>
        {({ primaryConnection, wifi }) => {
          if (!primaryConnection) return <Icon name="wifi-off" />;
          if (primaryConnection.type.includes('wireless') && wifi) {
            return (
              <box spacing={4}>
                <Icon name={getWifiStrength(wifi.strength)} marginBottom={8} />
                <label label={wifi.ssid} />
              </box>
            );
          }
          return <Icon name="cable" />;
        }}
      </With>
    </button>
  );
}

/** Displays an icon to denote the internet connection type. */
export function InternetConnection() {
  return (
    <box>
      <With value={primaryConnectionType}>
        {(type) => {
          if (!type) return <Icon name="wifi-off" tooltipText="No internet" />;
          else if (type === 'wifi') return <Icon name="wifi" tooltipText="Wifi Connection" />;
          else if (type === 'wired') return <Icon name="cable" tooltipText="Wired Connection" />;
          else return <Icon name="wifi-off" tooltipText="No internet" />;
        }}
      </With>
    </box>
  );
}
