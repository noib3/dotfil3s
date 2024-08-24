{
  config,
  lib,
  pkgs,
  colorscheme,
  hexlib,
  palette,
}:

{
  ags = import ./ags { inherit pkgs; };
  alacritty = import ./alacritty {
    inherit
      config
      lib
      pkgs
      palette
      ;
  };
  bat = import ./bat;
  bspwm = import ./bspwm;
  calcurse = import ./calcurse;
  direnv = import ./direnv;
  dmenu = import ./dmenu;
  dunst = import ./dunst;
  fd = import ./fd;
  fish = import ./fish {
    inherit
      config
      pkgs
      lib
      colorscheme
      palette
      ;
  };
  fusuma = import ./fusuma { inherit pkgs; };
  fuzzel = import ./fuzzel { inherit pkgs; };
  fzf = import ./fzf {
    inherit
      config
      pkgs
      colorscheme
      hexlib
      palette
      ;
  };
  git = import ./git { inherit colorscheme; };
  gpg = import ./gpg;
  gpg-agent = import ./gpg-agent { inherit pkgs; };
  grub = import ./grub;
  home-manager = import ./home-manager;
  hyprland = import ./hyprland { inherit pkgs; };
  kanshi = import ./kanshi { inherit config pkgs; };
  lazygit = import ./lazygit;
  lf = import ./lf { inherit pkgs; };
  mpris-proxy = import ./mpris-proxy { inherit pkgs; };
  mpv = import ./mpv { inherit pkgs; };
  neovim = import ./neovim;
  nix-index = import ./nix-index;
  picom = import ./picom;
  polybar = import ./polybar;
  qutebrowser = import ./qutebrowser {
    inherit
      config
      pkgs
      colorscheme
      palette
      hexlib
      ;
  };
  ripgrep = import ./ripgrep;
  skhd = import ./skhd;
  ssh-agent = import ./ssh-agent;
  starship = import ./starship { inherit (pkgs) lib; };
  sxhkd = import ./sxhkd;
  transmission = import ./transmission;
  tridactyl = import ./tridactyl;
  udiskie = import ./udiskie { inherit pkgs; };
  vivid = import ./vivid {
    inherit (pkgs) lib;
    inherit colorscheme palette;
  };
  wlsunset = import ./wlsunset { inherit pkgs; };
  yabai = import ./yabai;
  zathura = import ./zathura {
    inherit
      config
      pkgs
      colorscheme
      palette
      hexlib
      ;
  };
}