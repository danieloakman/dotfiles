import { Astal, Gdk, Gtk } from 'ags/gtk4';
import app from 'ags/gtk4/app';
import { Accessor, createState } from 'ags';
import { hideAllWindows, WindowName } from '../utils/window';
import Graphene from 'gi://Graphene?version=1.0';
import { noop } from '../utils/fn';
import { toAccessor } from '../utils/ags';
import { classes } from '../utils/styles';

const { TOP, BOTTOM, RIGHT, LEFT } = Astal.WindowAnchor;

export type ModalProps = Omit<
  JSX.IntrinsicElements['window'],
  'anchor' | `width${string}` | `height${string}`
> & {
  name: WindowName;
  children?: any;
  width?: number;
  height?: number;
  gdkmonitor?: Gdk.Monitor;
  transitionType?: Gtk.RevealerTransitionType;
  transitionDuration?: number;
  /** Called when the window is shown. */
  onShow?: (contentbox: Gtk.Box) => void;
};

/** Display a modal/dialog. */
export default function Modal({
  children,
  name,
  width,
  height,
  margin_top = 0,
  margin_bottom = 0,
  margin_start = 0,
  margin_end = 0,
  gdkmonitor,
  transitionType = Gtk.RevealerTransitionType.SLIDE_DOWN,
  transitionDuration = 300,
  halign = Gtk.Align.CENTER,
  valign = Gtk.Align.CENTER,
  cssClasses = [],
  onShow = noop,
  ...props
}: ModalProps) {
  let contentbox: Gtk.Box;
  const [visible, setVisible] = createState(false);
  const [revealed, setRevealed] = createState(false);

  function show() {
    setVisible(true);
    setRevealed(true);
    onShow(contentbox);
  }
  function hide() {
    setRevealed(false);
  }

  function init(self: Gtk.Window) {
    // override existing show and hide methods
    Object.assign(self, { show, hide });
  }

  return (
    <window
      {...props}
      visible={visible}
      name={name}
      namespace={name}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      gdkmonitor={gdkmonitor}
      application={app}
      anchor={TOP | BOTTOM | RIGHT | LEFT}
      $={init}
      onNotifyVisible={({ visible }) => {
        if (visible) contentbox.grab_focus();
      }}
      cssClasses={toAccessor(cssClasses).as((arr) => [...classes('bg-transparent'), ...arr])}
    >
      <Gtk.EventControllerKey
        onKeyPressed={({ widget }, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            widget.hide();
          }
        }}
      />
      <Gtk.GestureClick
        onPressed={({ widget }, _, x, y) => {
          const [, rect] = children.compute_bounds(widget);
          const position = new Graphene.Point({ x, y });

          if (!rect.contains_point(position)) {
            hideAllWindows();
          }
        }}
      />
      <revealer
        transitionType={transitionType}
        transitionDuration={transitionDuration}
        revealChild={revealed}
        halign={halign}
        valign={valign}
        onNotifyChildRevealed={({ childRevealed }) => setVisible(childRevealed)}
      >
        <box
          $={(self) => (contentbox = self)}
          focusable
          widthRequest={width}
          heightRequest={height}
          margin_top={margin_top}
          margin_bottom={margin_bottom}
          margin_start={margin_start}
          margin_end={margin_end}
        >
          {children}
        </box>
      </revealer>
    </window>
  );
}
