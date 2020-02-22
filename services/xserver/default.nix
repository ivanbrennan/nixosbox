pkgs:

{
  # Enable the X11 windowing system.
  enable = true;

  # Configure keyboard.
  layout = "us";
  xkbOptions = "ctrl:nocaps, shift:both_capslock";
  autoRepeatDelay = 200;
  autoRepeatInterval = 30;

  # Configure touchpad.
  libinput = {
    enable = true;
    naturalScrolling = true;
  };

  # desktopManager
  desktopManager.gnome3.enable = true;
  desktopManager.xterm.enable = false;
  desktopManager.default = "none";

  # windowManager
  windowManager = {
    i3 = {
      enable = true;
      configFile = i3/config;
      extraSessionCommands = ''
        eval $(gnome-keyring-daemon --daemonize)
        export SSH_AUTH_SOCK
      '';
    };

    xmonad = {
      enable = true;
      enableContribAndExtras = true;
    };
  };

  displayManager.lightdm.background = ''
    ${pkgs.nice-backgrounds}/share/backgrounds/gnome/moscow-subway.jpg
  '';
    # ${pkgs.nice-backgrounds}/share/backgrounds/gnome/owl-eye.jpg
    # ${pkgs.nice-backgrounds}/share/backgrounds/gnome/lookup.jpg

  displayManager.sessionCommands = ''
    ${pkgs.xorg.xrdb}/bin/xrdb -merge < ${./Xresources}
    ${pkgs.hsetroot}/bin/hsetroot -solid "#112026"
  '';
}
