#!/usr/bin/env bash
#
# Bootstraps a new (as in straight out of the box) macOS machine.

set -e

function echo_step() { printf '\033[34m==> \033[0m\033[1m'"$1"'\033[0m\n'; }
function echo_reboot() { printf '\r\033[31m==> \033[0m\033[1m'"$1"'\033[0m'; }
function error_exit() { printf '\033[31mERROR: \033[0m'"$1"'\n' && exit 1; }

function exit_if_not_darwin() {
  # Checks if the script is being run on a macOS machine. Echoes an error
  # message and exits if it isn't.

  [[ "$OSTYPE" == "darwin"* ]] \
    || error_exit "We are not on macOS."
}

function exit_if_root() {
  # Checks if the script is being run as root. Echoes an error message and
  # exits if it is.

  (( EUID != 0 )) \
    || error_exit "This script shouldn't be run as root."
}

function exit_if_sip_enabled() {
  # Checks if System Integrity Protection (SIP) is enabled. Echoes the steps to
  # disable it and exits if it is.

  [[ $(csrutil status | sed 's/[^:]*:[[:space:]]*\([^\.]*\).*/\1/') == "disabled" ]] \
    || error_exit "SIP needs to be disabled for the installation.

To disable it you need to:
  1. reboot;
  2. hold down Command-R while rebooting to go into recovery mode;
  3. open a terminal via Utilities -> Terminal;
  4. execute \033[1mcsrutil disable\033[0m;
  5. reboot.
"
}

function greetings_message() {
  # Echoes a greetings message listing the passwords needed for a full
  # installation. Then waits for user input.

  echo_step "Starting the installation"
  echo -e "\
You'll need:
  1. $(id -un)'s password to add $(id -un) to the sudoers file;
  2. your Firefox account's password to recover bookmarks, search history and
		 installed extensions;
  3. the remote server's Syncthing's Web GUI user name and password to fetch
     directories to sync;
  4. your GitHub account's password to add a new SSH key;
  5. your Logitech account's password to recover settings for the MX Master 2S
     mouse;
"
  read -n 1 -s -r -p "Press any key to continue:"
  printf '\n\n'
}

function command_line_tools() {
  # Checks if the command line tools are installed. Installs them if they
  # aren't.

  echo_step "Installing command line tools"

  if ! xcode-select --print-path &>/dev/null; then
    xcode-select --install &>/dev/null
    until xcode-select --print-path &>/dev/null; do
      sleep 5
    done
  fi

  printf '\n' && sleep 1
}

function whoami_to_sudoers() {
  # Adds the current user to the sudoers file with the NOPASSWD directive,
  # allowing it to issue sudo commands without being prompted for a password.

  echo_step "Adding $(id -un) to /private/etc/sudoers"

  printf "\n$(id -un)		ALL = (ALL) NOPASSWD: ALL\n" \
    | sudo tee -a /private/etc/sudoers &>/dev/null

  printf '\n' && sleep 1
}

function set_sys_defaults() {
  # Sets some macOS system defaults. Then asks for user input to set the
  # current timezone and the host name.

  echo_step "Setting macOS system preference defaults"

  # Enable trackpad's tap to click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad \
    Clicking -bool true

  # Show battery percentage in menu bar
  defaults write com.apple.menuextra.battery ShowPercent -bool true

  # Organize menu bar
  defaults write com.apple.systemuiserver menuExtras -array \
    "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" \
    "/System/Library/CoreServices/Menu Extras/AirPort.menu" \
    "/System/Library/CoreServices/Menu Extras/Battery.menu" \
    "/System/Library/CoreServices/Menu Extras/Clock.menu"

  # Show day of the week in menu bar
  defaults write com.apple.menuextra.clock \
    DateFormat -string "EEE d MMM  HH:mm"

  # Disable 'Are you sure you want to open this application?' dialog
  defaults write com.apple.LaunchServices LSQuarantine -bool false

  # Remove input sources from menu bar
  defaults write com.apple.TextInputMenu visible -bool false

  # Autohide Dock and set a really long show-on-hover delay (1000s ~> 16min)
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -int 1000

  # Set dock size
  defaults write com.apple.dock tilesize -float 50

  # Empty Dock
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock recent-others -array
  defaults write com.apple.dock show-recents -bool no

  # Autohide menu bar
  defaults write NSGlobalDomain _HIHideMenuBar -bool true

  # Set keyboard key repeat delays
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain KeyRepeat -int 2

  # Don't rearrange spaces based on most recent use
  defaults write com.apple.dock mru-spaces -bool false

  # Never start screen saver
  defaults -currentHost write com.apple.screensaver idleTime 0

  # Show scroll bars when scrolling
  defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

  # Enable quitting the Finder
  defaults write com.apple.finder QuitMenuItem -bool true

  # Show all files and extensions
  defaults write com.apple.finder AppleShowAllFiles -bool true

  # Don't show warning before changing an extension
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  # Group and sort files by name
  defaults write com.apple.finder FXPreferredGroupBy -string "Name"

  # Make ~ the default directory when opening a new window
  defaults write com.apple.finder NewWindowTarget -string "PfLo"
  defaults write com.apple.finder NewWindowTargetPath \
    -string "file://${HOME}/"

  # Remove 'Other' from login screen
  sudo defaults write /Library/Preferences/com.apple.loginwindow \
    SHOWOTHERUSERS_MANAGED -bool false

  # Never let the computer or the display go to sleep
  sudo pmset -a sleep 0
  sudo pmset -a displaysleep 0

  # Never dim the display while on battery power
  sudo pmset -a halfdim 0

  # Don't reopen any program after restarting
  defaults write com.apple.loginwindow TALLogoutSavesState -bool false
  defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false

  read -p "Choose a name for this machine:" hostname
  sudo scutil --set ComputerName "${hostname}"
  sudo scutil --set HostName "${hostname}"
  sudo scutil --set LocalHostName "${hostname}"
  sudo defaults write \
    /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName \
      -string "${hostname}"

  printf '\n'

  sudo systemsetup -listtimezones
  read -p "Set the current timezone from the list above:" timezone
  sudo systemsetup -settimezone "${timezone}" &>/dev/null

  killall Dock
  killall Finder
  killall SystemUIServer

  printf '\n' && sleep 1
}

function get_homebrew_bundle_brewfile() {
  # Checks if homebrew is installed, if not it installs it. Then it installs
  # the formulas taken from the Brewfile in the GitHub repo.

  echo_step "Downloading homebrew, then formulas from Brewfile"

  local path_homebrew_install_script=\
https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

  local path_brewfile=\
https://raw.githubusercontent.com/noib3/dotfiles/macOS/bootstrap/Brewfile

  which -s brew && brew update \
    || bash -c "$(curl -fsSL ${path_homebrew_install_script})"

  curl -fsSL ${path_brewfile} -o /tmp/Brewfile
  brew bundle install --file /tmp/Brewfile

  printf '\n' && sleep 1
}

function unload_finder {
  # Creates a service that quits Finder after the user logs in.

  echo_step "Creating a new service that quits Finder after loggin in"

  agent_scripts_dir="${HOME}/.local/agent-scripts"

  mkdir -p "${agent_scripts_dir}"

  cat << EOF > "${agent_scripts_dir}/unload-Finder.sh"
#!/usr/bin/env bash

launchctl unload /System/Library/LaunchAgents/com.apple.Finder.plist
osascript -e 'quit app "Finder"'
EOF

  chmod +x "${agent_scripts_dir}/unload-Finder.sh"

  mkdir -p "${HOME}/Library/LaunchAgents"
  cat << EOF > "${HOME}/Library/LaunchAgents/$(id -un).unload-Finder.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$(id -un).unload-Finder</string>
  <key>ProgramArguments</key>
  <array>
    <string>${agent_scripts_dir}/unload-Finder.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  launchctl load \
    "${HOME}/Library/LaunchAgents/$(id -un).unload-Finder.plist"

  printf '\n' && sleep 1
}

function add_remove_from_dock {
  # Add the "Remove from Dock" option when right-clicking the Finder's Dock
  # icon.

  echo_step "Adding the \"Remove from Dock\" option to the Finder's Dock icon"

  sudo mount -uw /

  sudo /usr/libexec/PlistBuddy \
    -c "Add :finder-quit:0 dict" \
    -c "Add :finder-quit:0:command integer 1004" \
    -c "Add :finder-quit:0:name string REMOVE_FROM_DOCK" \
    -c "Add :finder-running:0 dict" \
    -c "Add :finder-running:0:command integer 1004" \
    -c "Add :finder-running:0:name string REMOVE_FROM_DOCK" \
      /System/Library/CoreServices/Dock.app/Contents/Resources/DockMenus.plist

  killall Dock

  printf '\n' && sleep 1
}

function allow_accessibility_terminal_env {
  # The next function executes a script that needs /usr/bin/env and the
  # Terminal app to have accessibility permissions to allow osascript assistive
  # access.

  echo_step "qe"

  sudo tccutil --insert /usr/bin/env
  sudo tccutil --insert /System/Applications/Utilities/Terminal.app

  printf '\n' && sleep 1
}

function remove_finder_from_dock {
  # Creates a service that removes the Finder icon from the Dock after the user
  # logs in.

  echo_step "Creating a new service that removes Finder from the Dock"

  local agent_scripts_dir="${HOME}/.local/agent-scripts"
  sudo tee "${agent_scripts_dir}/remove-Finder-from-Dock.sh" >/dev/null << EOF
#!/usr/bin/env bash

osascript -e 'tell application "System Events"' \\
          -e    'tell UI element "Finder" of list 1 of process "Dock"' \\
          -e        'perform action "AXShowMenu"' \\
          -e        'click menu item "Remove from Dock" of menu 1' \\
          -e    'end tell' \\
          -e 'end tell'
EOF

  sudo chmod +x "${agent_scripts_dir}/remove-Finder-from-Dock.sh"

  echo_step "Say \"OK\" to the following dialog box"
  sleep 1

  # Call the script to trigger being asked for permissions
  "${agent_scripts_dir}/remove-Finder-from-Dock.sh" >/dev/null

  cat << EOF > \
    "${HOME}/Library/LaunchAgents/$(id -un).remove-Finder-from-Dock.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$(id -un).remove-Finder-from-Dock</string>
  <key>ProgramArguments</key>
  <array>
    <string>${agent_scripts_dir}/remove-Finder-from-Dock.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  launchctl load \
    "${HOME}/Library/LaunchAgents/"$(id -un)".remove-Finder-from-Dock.plist"

  printf '\n' && sleep 1
}

function add_to_finder_fav_pt1() {
  #

  echo_step "Adding ${HOME} and /usr/local/bin to the Finder's Favourites"

  mysides add "$(id -un)" "file://${HOME}"
  mysides add bin file:///usr/local/bin

  printf '\n' && sleep 1
}

function setup_dotfiles() {
  # Downloads the current dotfiles from the GitHub repo. Replaces the username
  # in firefox/userChrome.css and alacritty/alacritty.yml with $(id -un).
  # Lastly, it overrides ~/.config with the cloned repo.

  echo_step "Downloading and installing dotfiles from noib3/dotfiles (macOS \
branch)"

  git clone https://github.com/noib3/dotfiles.git --branch macOS /tmp/dotfiles

  /usr/local/opt/gnu-sed/libexec/gnubin/sed -i \
    "s@/Users/[^/]*/\(.*\)@/Users/$(id -un)/\1@g" \
    /tmp/dotfiles/alacritty/alacritty.yml \
    /tmp/dotfiles/firefox/userChrome.css

  rm -rf "${HOME}/.config"
  mv /tmp/dotfiles "${HOME}/.config"

  printf '\n' && sleep 1
}

function chsh_fish() {
  # Adds fish to the list of the valid shells, then sets fish as the chosen
  # login shell.

  echo_step "Setting up fish as the default shell"

  sudo sh -c "echo /usr/local/bin/fish >> /etc/shells"
  chsh -s /usr/local/bin/fish

  printf '\n' && sleep 1
}

function terminfo_alacritty() {
  # Downloads and installs the terminfo database for alacritty.

  echo_step "Setting up terminfo for alacritty"

  local path_alacritty_terminfo=\
https://raw.githubusercontent.com/alacritty/alacritty/master/extra/\
alacritty.info

  wget -P /tmp/ "${path_alacritty_terminfo}"
  sudo tic -xe alacritty,alacritty-direct /tmp/alacritty.info

  # Open Alacritty without being prompted for a "Are you sure.." dialog
  xattr -r -d com.apple.quarantine /Applications/Alacritty.app

  printf '\n' && sleep 1
}

function pip_install_requirements() {
  # Installs the python modules taken from the requirements.txt file in the
  # GitHub repo.

  echo_step "Downloading python modules"

  local path_python_requirements=\
https://raw.githubusercontent.com/noib3/dotfiles/macOS/bootstrap/\
requirements.txt

  wget -P /tmp "${path_python_requirements}"
  pip3 install -r /tmp/requirements.txt

  printf '\n' && sleep 1
}

function download_vimplug() {
  # Downloads vim-plug, a tool to manage Vim plugins.

  echo_step "Installing vim-plug and plugins"

  sh -c ' \
    curl \
      -fLo "${HOME}/.local/share/nvim/site/autoload/plug.vim" \
      --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
  '

  echo_step "Installing neovim plugins"
  nvim --headless +PlugInstall +qall &>/dev/null

  printf '\n' && sleep 1
}

function setup_firefox() {
  # Sets Firefox as the default browser. Symlinks the files in
  # ~/.config/firefox to all the user profiles. Downloads and installs the
  # no-new-tab version of Tridactyl. Installs the native messager to allow
  # Tridactyl to run other programs.

  echo_step "Setting up Firefox"

  # Open Firefox without being prompted for a "Are you sure.." dialog
  xattr -r -d com.apple.quarantine /Applications/Firefox.app

  printf "\n"
  echo_step "Set Firefox as the default browser"
  echo_step "Log into your Firefox account"
  echo_step "Wait for all the extensions to be installed"
  echo_step "Quit Firefox"
  sleep 2

  /Applications/Firefox.app/Contents/MacOS/firefox \
    --setDefaultBrowser "about:preferences#sync" &>/dev/null

  firefox_profiles="$(\
    ls "${HOME}/Library/Application Support/Firefox/Profiles/" | grep release \
  )"

  # Symlink firefox config
  for profile in "${firefox_profiles[@]}"; do
    ln -sf \
      "${HOME}/.config/firefox/user.js" \
      "${HOME}/Library/Application Support/Firefox/Profiles/${profile}/user.js"
    mkdir -p \
      "${HOME}/Library/Application Support/Firefox/Profiles/${profile}/chrome"
    ln -sf \
      "${HOME}/.config/firefox/userChrome.css" \
      "${HOME}/Library/Application Support/Firefox/Profiles/${profile}/chrome/"
    ln -f \
      "${HOME}/.config/firefox/userContent.css" \
      "${HOME}/Library/Application Support/Firefox/Profiles/${profile}/chrome/"
  done

  printf "\n"

  # Download and install tridactyl (no-new-tab version)

  local path_tridactyl_xpi=\
https://tridactyl.cmcaine.co.uk/betas/nonewtab/\
tridactyl_no_new_tab_beta-latest.xpi

  wget -P /tmp/ "${path_tridactyl_xpi}"

  echo_step "Accept Tridactyl installation"
  echo_step "Quit Firefox"
  sleep 2

  /Applications/Firefox.app/Contents/MacOS/firefox \
    /tmp/tridactyl_no_new_tab_beta-latest.xpi &>/dev/null

  local path_native_installer=\
https://raw.githubusercontent.com/tridactyl/tridactyl/master/native/install.sh

  # Install native messanger for tridactyl
  curl \
    -fsSl "${path_native_installer}" \
    -o /tmp/trinativeinstall.sh && sh /tmp/trinativeinstall.sh master

  printf '\n' && sleep 1
}

function setup_skim() {
  # Opens a dummy pdf file used to trigger the creation of Skim's property list
  # file in ~/Library/Preferences. Sets a few Skim preferences.

  echo_step "Setting up Skim preferences"

  # local path_plist_trigger_file=\
# https://github.com/noib3/dotfiles/blob/macOS/bootstrap/Skim_plist_trigger.pdf

  # wget -P /tmp "${path_plist_trigger_file}"

  # Open Skim without being prompted for a "Are you sure.." dialog
  xattr -r -d com.apple.quarantine /Applications/Skim.app

  # echo_step "After the following pdf opens, quit Skim"
  # sleep 1

  # # Open pdf with Skim to generate plist file
  /Applications/Skim.app/Contents/MacOS/Skim \
    /usr/local/lib/python3.9/site-packages/matplotlib/mpl-data/images/back.pdf

  # /Applications/Skim.app/Contents/MacOS/Skim /tmp/Skim_plist_trigger.pdf

  # Use Skim as the default PDF viewer
  duti -s net.sourceforge.skim-app.skim .pdf all

  # Preferences -> Sync -> Check for file changes
  defaults write -app Skim SKAutoCheckFileUpdate -int 1

  # Preferences -> Sync -> Reload automatically
  defaults write -app Skim SKAutoReloadFileUpdate -int 1

  # Preferences -> General -> Remember last page viewed
  defaults write -app Skim SKRememberLastPageViewed -int 1

  # Preferences -> General -> Open files: -> Fit
  defaults write -app Skim SKInitialWindowSizeOption -int 2

  # View -> Hide Contents Pane
  defaults write -app Skim SKLeftSidePaneWidth -int 0

  # View -> Hide Notes Pane
  defaults write -app Skim SKRightSidePaneWidth -int 0

  # View -> Hide Status Bar
  defaults write -app Skim SKShowStatusBar -int 0

  # View -> Toggle Toolbar
  plutil -replace "NSToolbar Configuration SKDocumentToolbar"."TB Is Shown" \
    -bool NO "${HOME}/Library/Preferences/net.sourceforge.skim-app.skim.plist"

  printf '\n' && sleep 1
}

function allow_accessibility() {
  # Allows accessibility permissions to skhd, spacebar and  yabai.

  echo_step "Allowing accessibility permissions to skhd, yabai and spacebar"

  local path_skhd_bin="$( \
    /usr/local/opt/coreutils/libexec/gnubin/readlink -f /usr/local/bin/skhd \
  )"
  local path_spacebar_bin="$( \
    /usr/local/opt/coreutils/libexec/gnubin/readlink -f /usr/local/bin/spacebar \
  )"
  local path_yabai_bin="$( \
    /usr/local/opt/coreutils/libexec/gnubin/readlink -f /usr/local/bin/yabai \
  )"

  sudo tccutil --insert "${path_skhd_bin}"
  sudo tccutil --insert "${path_spacebar_bin}"
  sudo tccutil --insert "${path_yabai_bin}"

  printf '\n' && sleep 1
}

function brew_start_services() {
  # Tells homebrew to start a few services.

  local services=( \
    redshift \
    skhd \
    spacebar \
    syncthing \
    transmission-cli \
    yabai \
  )

  echo_step "Starting ${services[0]}, ${services[1]} and other \
$((${#services[@]} - 2)) services with Homebrew"

  for service in "${services[@]}"; do
    brew services start "${service}"
  done

  printf '\n' && sleep 1
}

function yabai_install_sa() {
  # Installs the scripting-addition for yabai.

  echo_step "Installing yabai scripting-addition"

  sudo yabai --install-sa
  brew services restart yabai

  printf '\n' && sleep 1
}

function syncthing_sync_from_server() {
  # Opens a new Firefox window with this machine's and my remote server's
  # Syncthing Web GUI pages.

  echo_step "Opening Syncthing Web GUIs"

  local remote_droplet_name=Ocean
  local remote_sync_path=/home/noibe/Sync
  local_sync_path="${HOME}/Sync"

  printf "\n"
  echo_step "Remove Default Folder"
  echo_step "Set this machine's Device Name"
  echo_step "Add ${remote_droplet_name} to this machine's remote devices"
  echo_step "Sync ${remote_droplet_name}'s ${remote_sync_path} to \
${local_sync_path}"
  echo_step "Flag ${local_sync_path} as Send Only"
  echo_step "Set ${local_sync_path}'s Full Rescan Interval to 60 seconds"
  sleep 2

  /Applications/Firefox.app/Contents/MacOS/firefox \
    "http://localhost:8384/#" \
    "https://64.227.35.152:8384/#" &>/dev/null

  brew services stop syncthing
  xml ed --inplace \
    -u "/configuration/folder[@path='${local_sync_path}']/markerName" \
    -v "wallpapers" \
    "${HOME}/Library/Application Support/Syncthing/config.xml"
  rm -rf "${local_sync_path}/.stfolder"
  brew services start syncthing

  printf '\n' && sleep 1
}

function setup_sync_symlinks {
  # Sets up symlinks from various directories and files to ~/Sync.

  echo_step "Setting up symlinks to ~/Sync"

  ln -sf "${HOME}/Sync/private/ssh" "${HOME}/.ssh"

  rm -rf "${HOME}/.config"
  ln -s "${HOME}/Sync/dotfiles/macOS" "${HOME}/.config"

  for profile in "${firefox_profiles[@]}"; do
    ln -f \
      "${local_sync_path}/dotfiles/macOS/firefox/userContent.css" \
      "${HOME}/Library/Application Support/Firefox/Profiles/${profile}/chrome/"
  done

  mkdir -p "${HOME}/.local/share/ndiet"
  ln -s "${HOME}/Sync/code/ndiet/ndiet.py" /usr/local/bin/ndiet
  ln -s "${HOME}/Sync/code/ndiet/diets" "${HOME}/.local/share/ndiet/diets"
  ln -s \
    "${HOME}/Sync/code/ndiet/pantry.txt" \
    "${HOME}/.local/share/ndiet/pantry.txt"

  rm /usr/local/etc/auto-selfcontrol/config.json
  ln -sf \
    "${HOME}/Sync/private/auto-selfcontrol/config.json" \
    /usr/local/etc/auto-selfcontrol/config.json

  printf '\n' && sleep 1
}

function github_add_ssh_key() {
  # Creates a new ssh key for pushing to GitHub without having to input any
  # password. Adds the public key to the clipboard. Opens GitHub's settings
  # page in Firefox to add the newly generated key to the list of accepted
  # keys.

  echo_step "Creating new ssh key for GitHub"

  local github_user_email="riccardo.mazzarini@pm.me"

  printf "\n"
  echo_step "Leave the default value for the key path \
(${HOME}/.ssh/id_rsa)"
  echo_step "Overwrite the existing id_rsa file"
  echo_step "Leave the passphrase empty"

  ssh-keygen -t rsa -C "${github_user_email}"
  cat "${HOME}/Sync/private/ssh/id_rsa.pub" | pbcopy

  printf "\n"
  echo_step "The public key in id_rsa.pub is in the clipboard"
  echo_step "Log in to GitHub, choose a name for the new key and paste the \
key from the\n  clipboard"

  /Applications/Firefox.app/Contents/MacOS/firefox \
    "https://github.com/settings/ssh/new"

  # ssh -T git@github.com

  printf '\n' && sleep 1
}

function add_to_finder_fav_pt2() {
  #

  echo_step "Adding ${local_sync_path}/screenshots and \
${local_sync_path}/burocrazy to the Finder's Favourites"

  mysides add screenshots "file://${local_sync_path}/screenshots"
  mysides add burocrazy "file://${local_sync_path}/burocrazy"

  printf '\n' && sleep 1
}

function transmission_torrent_done_script {
  # Add a torrent-done script to Transmission.

  echo_step "Adding torrent-done notification script to Transmission"

  transmission-remote \
    --torrent-done-script "${HOME}/Sync/code/scripts/transmission/notify-done"

  printf '\n' && sleep 1
}

function start_auto_self_control {
  # Starts auto-selfcontrol

  echo_step "Starting auto-selfcontrol"

  auto-selfcontrol activate

  printf '\n ' && sleep 1
}

function set_wallpaper() {
  # Fetches the current $COLORSCHEME from fish/conf.d/exports.fish, then sets
  # the wallpaper to ~/Sync/wallpapers/$COLORSCHEME.png.

  local colorscheme="$(\
    grep 'set\s\+-x\s\+COLORSCHEME' "${HOME}/.config/fish/conf.d/exports.fish" \
    | /usr/local/opt/gnu-sed/libexec/gnubin/sed 's/set\s\+-x\s\+COLORSCHEME\s\+\([^\s]*\)/\1/'
  )"

  echo_step "Changing the wallpaper to ${colorscheme}.png"

  osascript -e \
    "tell application \"Finder\" to set desktop picture \
      to POSIX file \"${HOME}/Sync/wallpapers/${colorscheme}.png\"" &>/dev/null

  printf '\n' && sleep 1
}

function cleanup() {
  # Remove unneeded files, either already present in the machine or created
  # by a function in this script.

  echo_step "Cleaning up some files"

  sudo rm -rf "${HOME}/Public"
  sudo rm "${HOME}/.CFUserTextEncoding"
  sudo rm "${HOME}/Downloads/.localized"
  rm "${HOME}/.wget-hsts"

  # Find every .DS_Store file in / and delete them.
  sudo mount -uw /
  osascript -e 'quit app "Finder"'
  fd -uu ".DS_Store" / -X sudo rm -f

  mkdir -p "${HOME}/.cache"

  printf '\n' && sleep 1
}

function todo_dot_md() {
  # Create a TODO.md file in $(id -un)'s home folder listing the things left to
  # do to get back to full speed

  # Logitech options -> Zoom with wheel,
  # Logitech options -> Point & Scroll -> Scroll direction -> Natural,
  # Thumb wheel direction -> Inverted
  # Smooth scrolling -> Disabled
  # Set pointer and scrolling speed

  # Firefox -> Default Zoom -> 133%
  # Firefox bitwarden login

  # Log back in into all the websites (Bitwarden, Google, YouTube, Reddit,
  # etc..)
  # Bitwarden -> Settings -> Vault timeout -> Never

  # Firefox add private window permissions to all extensions

  # Take a screenshot to trigger being asked for screen recording permissions
  # for skhd (System Preferences -> Security and Privacy -> Screen
  # recording -> skdh)

  # Uncheck System Preferences -> Mission Control -> When switching to an
  # application, switch to a Space with open windows for the application.

  cat > $HOME/TODO.md << EOF
# TODO.md

1. do this;
2. do that;
3. attach an external display and rearrange so that the external is the main
   one;
4. login youtube, switch account and enable dark mode and english;
5. log into bitwarden, unlock it, then Settings -> Vault timeout -> Never;
EOF
  printf '\n' && sleep 1
}

function countdown_reboot() {
  # Display a nine second countdown, then reboot.

  for n in {9..0}; do
    echo_reboot "Rebooting in $n"
    [[ ${n} == 0 ]] || sleep 1
  done

  printf '\n\n'
  osascript -e "tell app \"System Events\" to restart"
}

# These functions are part of a generic installation aiming to fully reproduce
# my setup.

exit_if_not_darwin
exit_if_root
exit_if_sip_enabled
greetings_message
# command_line_tools
# whoami_to_sudoers
# set_sys_defaults
# get_homebrew_bundle_brewfile
# unload_finder
# add_remove_from_dock
# allow_accessibility_terminal_env
# remove_finder_from_dock
# add_to_finder_fav_pt1
# setup_dotfiles
# chsh_fish
# terminfo_alacritty
# pip_install_requirements
# download_vimplug
# setup_firefox
# setup_skim
# allow_accessibility
# brew_start_services
# yabai_install_sa

# These functions are specific to my particular setup. Things like configuring
# settings for my Logitech MX Master mouse, adding a new SSH key to my GitHub
# account or synching directories from a remote server.

# syncthing_sync_from_server
# setup_sync_symlinks
# github_add_ssh_key
# add_to_finder_fav_pt2
# transmission_torrent_done_script
# start_auto_self_control
# set_wallpaper

# Cleanup leftover files, create a TODO.md file listing the things left to do
# to get back to full speed, reboot the system.

# cleanup
# todo_dot_md
# countdown_reboot