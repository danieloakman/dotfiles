{ env, ... }: {
  home-manager.users.${env.user}.programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 0;
        margin = "0";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [
          "network"
          "bluetooth"
          "cpu"
          "memory"
          # "temperature"
          "battery"
          "clock"
          "tray"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          warp-on-scroll = false;
          format = "{name}";
          on-click = "activate";
          sort-by-number = true;
        };

        "hyprland/window" = {
          format = "{}";
          separate-outputs = false;
        };

        network = {
          format-wifi = "  {essid} {signalStrength}%";
          format-ethernet = "  {ifname}";
          format-disconnected = "  Disconnected";
          format-linked = "  {ifname}";
          max-length = 50;
          tooltip-format = "{ifname} via {gwaddr}";
          tooltip-format-wifi = "{essid} ({signalStrength}%)
IP: {ipaddr}";
          tooltip-format-ethernet = "{ifname}
IP: {ipaddr}";
          tooltip-format-disconnected = "Disconnected";
          on-click = "nm-connection-editor";
        };

        bluetooth = {
          format = " {device_battery_percentage}%";
          format-connected = " {device_alias} {device_battery_percentage}%";
          format-connected-battery = " {device_alias} {device_battery_percentage}%";
          format-device-prefix = " ";
          format-disabled = " Disabled";
          format-disconnected = " Disconnected";
          format-off = " Off";
          format-on = " On";
          format-pairing = " Pairing";
          format-tooltip = "{num_connections} connected";
          format-tooltip-connection = "{device_alias} {device_battery_percentage}%";
          interval = 30;
          max-length = 25;
          tooltip = true;
          on-click = "blueman-manager";
          on-click-middle = "";
          on-click-right = "";
        };

        cpu = {
          interval = 1;
          format = "  {usage}%";
          max-length = 10;
          tooltip = true;
          tooltip-format = "CPU: {usage}%";
          on-click = "";
          on-click-middle = "";
          on-click-right = "";
        };

        memory = {
          interval = 1;
          format = "  {percentage}%";
          max-length = 10;
          tooltip = true;
          tooltip-format = "Memory: {used:0.1f}GiB / {total:0.1f}GiB ({percentage}%)";
          on-click = "";
          on-click-middle = "";
          on-click-right = "";
        };

        # temperature = {
        #   hwmon-path-abs = "/sys/class/hwmon/hwmon2/temp1_input";
        #   input-filename = "temp1_input";
        #   interval = 1;
        #   format = "  {temperatureC}°C";
        #   max-length = 10;
        #   tooltip = true;
        #   tooltip-format = "Temperature: {temperatureC}°C";
        #   on-click = "";
        #   on-click-middle = "";
        #   on-click-right = "";
        # };

        battery = {
          bat = "BAT0";
          interval = 30;
          states = {
            warning = 20;
            critical = 10;
          };
          format = "  {capacity}% {timeTo}";
          format-charging = "  {capacity}% {timeTo}";
          format-plugged = "  {capacity}%";
          format-alt = "{capacity}%";
          format-full = "  {capacity}%";
          format-icons = [ "" "" "" "" "" ];
          max-length = 25;
          tooltip = true;
          tooltip-format = "{capacity}% {timeTo}";
          on-click = "";
          on-click-middle = "";
          on-click-right = "";
        };

        clock = {
          timezone = "Australia/Sydney";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d %I:%M %p}";
          format = "  {:%I:%M %p}";
          max-length = 25;
          interval = 1;
          format-calendar = "<span color='#ecc6d0'><b>{}</b></span>";
          format-calendar-weeks = "<span color='#99ccdd'><b>W{:%U}</b></span>";
          format-calendar-weekdays = "<span color='#ff6699'><b>{}</b></span>";
          on-click = "";
          on-click-middle = "";
          on-click-right = "";
        };

        tray = {
          icon-size = 21;
          spacing = 0;
        };
      };
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free Solid", "Font Awesome 6 Brands", "Font Awesome 6 Free", "Roboto", "Helvetica Neue", "Liberation Sans", "Arial", sans-serif;
        font-size: 13px;
        font-style: normal;
        font-weight: normal;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.5);
        border-bottom: 3px solid rgba(100, 114, 125, 0.5);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      window#waybar.termite {
        background-color: #3F3F3F;
      }

      window#waybar.chromium {
        background-color: #000000;
        border: none;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
        border-bottom: 3px solid transparent;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
        box-shadow: inherit;
        border-bottom: 3px solid #ffffff;
      }

      #workspaces button.active {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #workspaces button.urgent {
        background-color: #eb4d4b;
      }

      #mode {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #bluetooth,
      #pulseaudio,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #mpd {
        padding: 0 10px;
        margin: 0 4px;
        color: #ffffff;
      }

      #clock {
        background-color: #64727D;
      }

      #battery {
        background-color: #ffffff;
        color: #000000;
      }

      #battery.charging, #battery.plugged {
        color: #ffffff;
        background-color: #26A65B;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }

      #battery.critical:not(.charging) {
        background-color: #f53c3c;
        color: #ffffff;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      label:focus {
        background-color: #000000;
      }

      #cpu {
        background-color: #2ecc71;
        color: #000000;
      }

      #memory {
        background-color: #9b59b6;
      }

      #disk {
        background-color: #964B00;
      }

      #network {
        background-color: #2980b9;
      }

      #network.disconnected {
        background-color: #f53c3c;
      }

      #bluetooth {
        background-color: #5dade2;
      }

      #bluetooth.disconnected {
        background-color: #f53c3c;
      }

      #bluetooth.off {
        background-color: #95a5a6;
      }

      #pulseaudio {
        background-color: #f1c40f;
        color: #000000;
      }

      #pulseaudio.muted {
        background-color: #90b1b6;
      }

      #custom-media {
        background-color: #66cc99;
        color: #2a5f45;
        min-width: 100px;
      }

      #custom-media.custom-spotify {
        background-color: #66cc99;
      }

      #custom-media.custom-vlc {
        background-color: #ffa000;
      }

      #temperature {
        background-color: #f0932b;
      }

      #temperature.critical {
        background-color: #eb4d4b;
      }

      #tray {
        background-color: #2980b9;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #eb4d4b;
      }

      #idle_inhibitor {
        background-color: #2d3436;
      }

      #idle_inhibitor.activated {
        background-color: #ecf0f1;
        color: #2d3436;
      }

      #mpd {
        background-color: #66cc99;
        color: #2a5f45;
      }

      #mpd.disconnected {
        background-color: #f53c3c;
      }

      #mpd.stopped {
        background-color: #90b1b6;
      }

      #mpd.paused {
        background-color: #51a37a;
      }

      #language {
        background: #00b093;
        color: #740864;
        padding: 0 5px;
        margin: 0 5px;
        min-width: 16px;
      }

      #keyboard-state {
        background: #97e1ad;
        color: #000000;
        padding: 0 0px;
        margin: 0 5px;
        min-width: 16px;
      }

      #keyboard-state > label {
        padding: 0 5px;
      }

      #keyboard-state > label.locked {
        background: rgba(0, 0, 0, 0.2);
      }

      #scratchpad {
        background: rgba(0, 150, 136, 0.8);
      }

      #scratchpad.empty {
        background-color: transparent;
      }
    '';
  };
}
