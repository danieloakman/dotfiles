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
          # "bluetooth"
          "cpu"
          "memory"
          # "temperature"
          "pipewire"
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

        # bluetooth = {
        #   format = " {device_battery_percentage}%";
        #   format-connected = " {device_alias} {device_battery_percentage}%";
        #   format-connected-battery = " {device_alias} {device_battery_percentage}%";
        #   format-device-prefix = " ";
        #   format-disabled = " Disabled";
        #   format-disconnected = " Disconnected";
        #   format-off = " Off";
        #   format-on = " On";
        #   format-pairing = " Pairing";
        #   format-tooltip = "{num_connections} connected";
        #   format-tooltip-connection = "{device_alias} {device_battery_percentage}%";
        #   interval = 30;
        #   max-length = 25;
        #   tooltip = true;
        #   on-click = "blueman-manager";
        #   on-click-middle = "";
        #   on-click-right = "";
        # };

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

        pipewire = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-bluetooth-muted = "  {format_source}";
          format-muted = "  {format_source}";
          format-source = "  {volume}%";
          format-source-muted = "  ";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" "" ];
          };
          on-click = "pavucontrol";
          on-click-middle = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          scroll-step = 5;
          reverse-scroll = false;
          tooltip = true;
          tooltip-format = "{desc}, {volume}%";
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
        background-color: transparent;
        border-bottom: 2px solid #ffffff;
        color: #ffffff;
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
        border-bottom: 2px solid transparent;
      }

      #workspaces button:hover {
        background: transparent;
        border-bottom: 2px solid #ffffff;
      }

      #workspaces button.active {
        background-color: transparent;
        border-bottom: 2px solid #ffffff;
        color: #ffffff;
      }

      #workspaces button.urgent {
        background-color: transparent;
        color: #eb4d4b;
        border-bottom: 2px solid #eb4d4b;
      }

      #mode {
        background-color: transparent;
        border-bottom: 2px solid #ffffff;
        color: #ffffff;
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
      #pipewire,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #mpd {
        padding: 0 2px;
        margin: 0 1px;
        background-color: transparent;
      }

      #clock {
        color: #ffffff;
        border-bottom: 2px solid #ffffff;
      }

      #battery {
        color: #ffffff;
        border-bottom: 2px solid #ffffff;
      }

      #battery.charging, #battery.plugged {
        color: #26A65B;
        border-bottom: 2px solid #26A65B;
      }

      #battery.critical:not(.charging) {
        color: #f53c3c;
        border-bottom: 2px solid #f53c3c;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      @keyframes blink {
        to {
          color: #ffffff;
          border-bottom-color: #ffffff;
        }
      }

      #cpu {
        color: #2ecc71;
        border-bottom: 2px solid #2ecc71;
      }

      #memory {
        color: #9b59b6;
        border-bottom: 2px solid #9b59b6;
      }

      #disk {
        color: #964B00;
        border-bottom: 2px solid #964B00;
      }

      #network {
        color: #2980b9;
        border-bottom: 2px solid #2980b9;
      }

      #network.disconnected {
        color: #f53c3c;
        border-bottom: 2px solid #f53c3c;
      }

      #bluetooth {
        color: #5dade2;
        border-bottom: 2px solid #5dade2;
      }

      #bluetooth.disconnected {
        color: #f53c3c;
        border-bottom: 2px solid #f53c3c;
      }

      #bluetooth.off {
        color: #95a5a6;
        border-bottom: 2px solid #95a5a6;
      }

      #pipewire {
        color: #f1c40f;
        border-bottom: 2px solid #f1c40f;
      }

      #pipewire.muted {
        color: #90b1b6;
        border-bottom: 2px solid #90b1b6;
      }

      #custom-media {
        color: #66cc99;
        border-bottom: 2px solid #66cc99;
        min-width: 100px;
      }

      #custom-media.custom-spotify {
        color: #66cc99;
        border-bottom: 2px solid #66cc99;
      }

      #custom-media.custom-vlc {
        color: #ffa000;
        border-bottom: 2px solid #ffa000;
      }

      #temperature {
        color: #f0932b;
        border-bottom: 2px solid #f0932b;
      }

      #temperature.critical {
        color: #eb4d4b;
        border-bottom: 2px solid #eb4d4b;
      }

      #tray {
        color: #2980b9;
        border-bottom: 2px solid #2980b9;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        color: #eb4d4b;
        border-bottom: 2px solid #eb4d4b;
      }

      #idle_inhibitor {
        color: #2d3436;
        border-bottom: 2px solid #2d3436;
      }

      #idle_inhibitor.activated {
        color: #ecf0f1;
        border-bottom: 2px solid #ecf0f1;
      }

      #mpd {
        color: #66cc99;
        border-bottom: 2px solid #66cc99;
      }

      #mpd.disconnected {
        color: #f53c3c;
        border-bottom: 2px solid #f53c3c;
      }

      #mpd.stopped {
        color: #90b1b6;
        border-bottom: 2px solid #90b1b6;
      }

      #mpd.paused {
        color: #51a37a;
        border-bottom: 2px solid #51a37a;
      }

      #language {
        color: #00b093;
        border-bottom: 2px solid #00b093;
        padding: 0 2px;
        margin: 0 1px;
        min-width: 16px;
      }

      #keyboard-state {
        color: #97e1ad;
        border-bottom: 2px solid #97e1ad;
        padding: 0;
        margin: 0 1px;
        min-width: 16px;
      }

      #keyboard-state > label {
        padding: 0 2px;
      }

      #keyboard-state > label.locked {
        background: transparent;
      }

      #scratchpad {
        color: rgba(0, 150, 136, 1);
        border-bottom: 2px solid rgba(0, 150, 136, 1);
      }

      #scratchpad.empty {
        background-color: transparent;
        border-bottom: 2px solid transparent;
      }
    '';
  };
}
