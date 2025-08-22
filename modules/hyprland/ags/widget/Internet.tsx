import { createBinding, createComputed, createConnection, createState, For, With } from 'ags';
import { Gtk } from 'ags/gtk4';
import Network from 'gi://AstalNetwork';
import { Icon } from '../components/Icon';
import { UnwrapAccessor } from '../utils/ags';
import { iife, multiComparator } from '../utils/fn';
import Accordion from '../components/Accordion';
import { classes } from '../utils/styles';
import { Fragment } from 'ags';
import { execAsync } from 'ags/process';

const network = Network.get_default();

export const wifi = createBinding(network, 'wifi');
export const client = createBinding(network, 'client');

export type NetworkClient = UnwrapAccessor<typeof client>;
export type PrimaryConnection = ReturnType<UnwrapAccessor<NetworkClient['get_primary_connection']>>;

/** The primary internet connection. Can be wired or wireless or none. */
export const primaryConnection = iife(() => {
  const get = (): PrimaryConnection | null => network.get_client().get_primary_connection();
  return createConnection(
    get(),
    [network, 'notify::primary', get],
    [network, 'notify::wifi', get],
    [network, 'notify::connectivity', get],
  );
});
export const allConnections = iife(() => {
  const get = () => network.get_client().get_connections();
  return createConnection(
    get(),
    [network, 'notify', get],
    [network, 'notify::primary', get],
    [network, 'notify::wifi', get],
    [network, 'notify::connectivity', get],
  );
});
export const activeConnections = iife(() => {
  const get = () => network.get_client().get_active_connections();
  return createConnection(
    get(),
    [network, 'notify::state', get],
    [network, 'notify::connectivity', get],
    [network, 'notify::primary', get],
    [network, 'notify::wifi', get],
  );
});
const connections = createComputed([allConnections, activeConnections], (...v) => v);

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
  const [isOpen, setIsOpen] = createState(false);

  return (
    <Accordion title="Internet" open={isOpen} onOpenChange={setIsOpen}>
      <With value={connections}>
        {([allConnections, activeConnections]) => (
          <box spacing={4} cssClasses={classes('py-sm')} orientation={Gtk.Orientation.VERTICAL}>
            {/* TODO: show "Open Network config" here: */}
            {/* <button>
              <box></box>
            </button> */}

            {allConnections
              .map((connection) => {
                const isActive = activeConnections.some((c) => c.get_id() === connection.get_id());
                return { connection, isActive };
              })
              .sort(
                multiComparator(
                  (a, b) => (b.isActive && a.isActive ? 0 : b.isActive ? 1 : -1),
                  (a, b) => a.connection.get_id().localeCompare(b.connection.get_id()),
                ),
              )
              .map(({ connection, isActive }) => {
                return (
                  <centerbox cssClasses={classes('rounded-sm', 'bg-bg-color', 'btn-ghost')}>
                    <button
                      $type="start"
                      cssClasses={classes('bg-transparent')}
                      hexpand
                      label={`${
                        isActive ? '🟢' : '🔴'
                      } ${connection.get_id()} (${connection.get_connection_type()})`}
                      onClicked={() => {
                        execAsync(`nmcli c ${isActive ? 'down' : 'up'} "${connection.get_id()}"`)
                          .then(() =>
                            console.log(`${isActive ? 'Down' : 'Up'} ${connection.get_id()}`),
                          )
                          .catch(console.error);
                      }}
                    />

                    <button $type="end" cssClasses={classes('bg-transparent')}>
                      <Icon name="chevron-down" />
                    </button>
                  </centerbox>
                );
              })}
          </box>
        )}
      </With>
      {/* <For each={allConnections}>
          {(connection) => (
            <centerbox>
              <button
                $type="start"
                hexpand
                label={`${connection.get_id()} (${connection.get_connection_type()})`}
                onClicked={() => {}}
              />

              <button $type="end">
                <Icon name="chevron-down" />
              </button>
            </centerbox>
          )}
        </For> */}
    </Accordion>
  );
}

function CurrentConnection() {
  return (
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
        return (
          <box spacing={4}>
            <Icon name="cable" />
            <label label={primaryConnection.get_id()} />
          </box>
        );
      }}
    </With>
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
