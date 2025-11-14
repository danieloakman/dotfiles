import { createBinding, createComputed, createConnection, With } from 'ags';
import { Gtk } from 'ags/gtk4';
import Network from 'gi://AstalNetwork';
import { Icon } from '../components/Icon';
import { createBooleanState, UnwrapAccessor } from '../utils/ags';
import { iife, multiComparator } from '@/js-utils';
import Accordion from '../components/Accordion';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { Hr } from '@/components/Separators';

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

export default function Internet() {
  const [isOpen, { toggle: toggleIsOpen }] = createBooleanState(false);

  return (
    <Accordion
      title={() => (
        <box spacing={4}>
          <InternetConnection />
          <label label={primaryConnection((c) => c?.get_id() ?? 'Internet')} />
        </box>
      )}
      open={isOpen}
      onOpenChange={toggleIsOpen}
    >
      <With value={connections}>
        {([allConnections, activeConnections]) => (
          <box spacing={4} cssClasses={classes('py-sm')} orientation={Gtk.Orientation.VERTICAL}>
            <button
              cssClasses={classes('btn-ghost')}
              label="Open Network Connection Manager"
              onClicked={() =>
                execAsync('nm-connection-editor').catch((err) =>
                  console.error('Failed to open network connection manager', err),
                )
              }
            />

            <Hr />

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
                  <centerbox cssClasses={classes('rounded', 'bg-bg-color', 'btn-ghost')}>
                    <button
                      $type="start"
                      cssClasses={classes('bg-transparent')}
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
    </Accordion>
  );
}

/** Displays an icon to denote the internet connection type. */
export function InternetConnection() {
  const computed = createComputed([primaryConnectionType, wifi], (type, wifi) => ({
    type,
    wifi,
  }));
  return (
    <box>
      <With value={computed}>
        {({ type, wifi }) => {
          if (!type) return <Icon name="wifi-off" tooltipText="No internet" />;
          else if (type === 'wifi')
            return (
              <Icon
                name={wifi ? getWifiStrength(wifi.get_strength()) : 'wifi'}
                tooltipText="Wifi Connection"
              />
            );
          else if (type === 'wired') return <Icon name="cable" tooltipText="Wired Connection" />;
          else return <Icon name="wifi-off" tooltipText="No internet" />;
        }}
      </With>
    </box>
  );
}
