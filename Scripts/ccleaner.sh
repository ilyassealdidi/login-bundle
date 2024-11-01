#!/usr/bin/env bash

set -E
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
}

# Default arguments
update=false

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-u]

A Mac Cleaning up Utility by fwartner
https://github.com/mac-cleanup/mac-cleanup-sh

Available options:

-h, --help       Print this help and exit
-d, --dry-run    Print approx space to be cleaned
-v, --verbose    Print script debug info
-u, --update     Run brew update
EOF
	exit
}

# shellcheck disable=SC2034  # Unused variables left for readability
setup_colors() {
	if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	else
		NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
	fi
}

msg() {
  if [ -z "$dry_run" ]; then
	  echo >&2 -e "${1-}"
	fi
}

die() {
	local msg=$1
	local code=${2-1} # default exit status 1
	msg "$msg"
	exit "$code"
}

parse_params() {
	# default values of variables set from params
	update=false

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		-d | --dry-run) dry_run=true ;;
		--no-color) NO_COLOR=1 ;;
		-u | --update) update=true ;; # update flag
		-n) true ;;                   # This is a legacy option, now default behaviour
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	return 0
}

parse_params "$@"
setup_colors

deleteCaches() {
	local cacheName=$1
	shift
	local paths=("$@")
	echo "Initiating cleanup ${cacheName} cache..."
	for folderPath in "${paths[@]}"; do
		if [[ -d ${folderPath} ]]; then
			dirSize=$(du -hs "${folderPath}" | awk '{print $1}')
			echo "Deleting ${folderPath} to free up ${dirSize}..."
			rm -rfv "${folderPath}"
		fi
	done
}

bytesToHuman() {
	b=${1:-0}
	d=''
	s=1
	S=(Bytes {K,M,G,T,E,P,Y,Z}iB)
	while ((b > 1024)); do
		d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
		b=$((b / 1024))
		((s++))
	done
	if [ -z "$dry_results" ]; then
    msg "$b$d ${S[$s]} of space was cleaned up"
  else
    msg "Approx $b$d ${S[$s]} of space will be cleaned up"
  fi
}

count_dry() {
  for path in "${path_list[@]}"; do
    if [ -d "$path" ] || [ -f "$path" ]; then
      temp_dry_results=$(sudo du -ck "$path" | tail -1 | awk '{ print $1 }')
      dry_results="$((dry_results+temp_dry_results))"
    fi
  done
}

remove_paths() {
  if [ -z "$dry_run" ]; then
    for path in "${path_list[@]}"; do
      rm -rfv "$path" &>/dev/null
    done
    unset path_list
  fi
}

collect_paths() {
  path_list+=("$@")
}

# Ask for the administrator password upfront
sudo -v

HOST=$(whoami)

# Keep-alive sudo until `mac-cleanup.sh` has finished
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

# Enable extended regex
shopt -s extglob

oldAvailable=$(df / | tail -1 | awk '{print $4}')

collect_paths /Volumes/*/.Trashes/*
collect_paths ~/.Trash/*
msg 'Emptying the Trash 🗑 on all mounted volumes and the main HDD...'
remove_paths

collect_paths /Library/Caches/*
collect_paths /System/Library/Caches/*
collect_paths ~/Library/Caches/*
collect_paths /private/var/folders/bh/*/*/*/*
msg 'Clearing System Cache Files...'
remove_paths

collect_paths /private/var/log/asl/*.asl
collect_paths /Library/Logs/DiagnosticReports/*
collect_paths /Library/Logs/CreativeCloud/*
collect_paths /Library/Logs/Adobe/*
collect_paths /Library/Logs/adobegc.log
collect_paths ~/Library/Containers/com.apple.mail/Data/Library/Logs/Mail/*
collect_paths ~/Library/Logs/CoreSimulator/*
msg 'Clearing System Log Files...'
remove_paths

if [ -d ~/Library/Logs/JetBrains/ ]; then
  collect_paths ~/Library/Logs/JetBrains/*/
  msg 'Clearing all application log files from JetBrains...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Adobe/ ]; then
  collect_paths ~/Library/Application\ Support/Adobe/Common/Media\ Cache\ Files/*
  msg 'Clearing Adobe Cache Files...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Google/Chrome/ ]; then
  collect_paths ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache/*
  msg 'Clearing Google Chrome Cache Files...'
  remove_paths
fi

collect_paths ~/Music/iTunes/iTunes\ Media/Mobile\ Applications/*
msg 'Cleaning up iOS Applications...'
remove_paths

collect_paths ~/Library/Application\ Support/MobileSync/Backup/*
msg 'Removing iOS Device Backups...'
remove_paths

collect_paths ~/Library/Developer/Xcode/DerivedData/*
collect_paths ~/Library/Developer/Xcode/Archives/*
collect_paths ~/Library/Developer/Xcode/iOS Device Logs/*
msg 'Cleaning up XCode Derived Data and Archives...'
remove_paths

if type "xcrun" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up iOS Simulators...'
    osascript -e 'tell application "com.apple.CoreSimulator.CoreSimulatorService" to quit' &>/dev/null
    osascript -e 'tell application "iOS Simulator" to quit' &>/dev/null
    osascript -e 'tell application "Simulator" to quit' &>/dev/null
    xcrun simctl shutdown all &>/dev/null
    xcrun simctl erase all &>/dev/null
  else
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/!(Library|var|tmp|Media)
    collect_paths /Users/wah/Library/Developer/CoreSimulator/Devices/*/data/Library/!(PreferencesCaches|Caches|AddressBook)
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/*
    collect_paths ~/Library/Developer/CoreSimulator/Devices/*/data/Library/AddressBook/AddressBook*
  fi
fi

# support deleting Dropbox Cache if they exist
if [ -d "/Users/${HOST}/Dropbox" ]; then
  collect_paths ~/Dropbox/.dropbox.cache/*
  msg 'Clearing Dropbox 📦 Cache Files...'
  remove_paths
fi

if [ -d ~/Library/Application\ Support/Google/DriveFS/ ]; then
  collect_paths ~/Library/Application\ Support/Google/DriveFS/[0-9a-zA-Z]*/content_cache
  msg 'Clearing Google Drive File Stream Cache Files...'
  killall "Google Drive File Stream"
  remove_paths
fi

if type "composer" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up composer...'
    composer clearcache --no-interaction &>/dev/null
  else
    collect_paths ~/Library/Caches/composer
  fi
fi

# Deletes Steam caches, logs, and temp files
# -Astro
if [ -d ~/Library/Application\ Support/Steam/ ]; then
  collect_paths ~/Library/Application\ Support/Steam/appcache
  collect_paths ~/Library/Application\ Support/Steam/depotcache
  collect_paths ~/Library/Application\ Support/Steam/logs
  collect_paths ~/Library/Application\ Support/Steam/steamapps/shadercache
  collect_paths ~/Library/Application\ Support/Steam/steamapps/temp
  collect_paths ~/Library/Application\ Support/Steam/steamapps/download
  msg 'Clearing Steam Cache, Log, and Temp Files...'
  remove_paths
fi

# Deletes Minecraft logs
# -Astro
if [ -d ~/Library/Application\ Support/minecraft ]; then
  collect_paths ~/Library/Application\ Support/minecraft/logs
  collect_paths ~/Library/Application\ Support/minecraft/crash-reports
  collect_paths ~/Library/Application\ Support/minecraft/webcache
  collect_paths ~/Library/Application\ Support/minecraft/webcache2
  collect_paths ~/Library/Application\ Support/minecraft/crash-reports
  collect_paths ~/Library/Application\ Support/minecraft/*.log
  collect_paths ~/Library/Application\ Support/minecraft/launcher_cef_log.txt
  if [ -d ~/Library/Application\ Support/minecraft/.mixin.out ]; then
    collect_paths ~/Library/Application\ Support/minecraft/.mixin.out
  fi
  msg 'Clearing Minecraft Cache and Log Files...'
  remove_paths
fi

# Deletes Lunar Client logs (Minecraft alternate client)
# -Astro
if [ -d ~/.lunarclient ]; then
  collect_paths ~/.lunarclient/game-cache
  collect_paths ~/.lunarclient/launcher-cache
  collect_paths ~/.lunarclient/logs
  collect_paths ~/.lunarclient/offline/*/logs
  collect_paths ~/.lunarclient/offline/files/*/logs
  msg 'Deleting Lunar Client logs and caches...'
  remove_paths
fi

# Deletes Wget logs
# -Astro
if [ -d ~/wget-log ]; then
  collect_paths ~/wget-log
  collect_paths ~/.wget-hsts
  msg 'Deleting Wget log and hosts file...'
  remove_paths
fi

# Deletes Cacher logs
# I dunno either
# -Astro
if [ -d ~/.cacher ]; then
  collect_paths ~/.cacher/logs
  msg 'Deleting Cacher logs...'
  remove_paths
fi

# Deletes Android (studio?) cache
# -Astro
if [ -d ~/.android ]; then
  collect_paths ~/.android/cache
  msg 'Deleting Android cache...'
  remove_paths
fi

# Clears Gradle caches
# -Astro
if [ -d ~/.gradle ]; then
  collect_paths ~/.gradle/caches
  msg 'Clearing Gradle caches...'
  remove_paths
fi

# Deletes Kite Autocomplete logs
# -Astro
if [ -d ~/.kite ]; then
  collect_paths ~/.kite/logs
  msg 'Deleting Kite logs...'
  remove_paths
fi

if type "brew" &>/dev/null; then
  if [ "$update" = true ]; then
    msg 'Updating Homebrew Recipes...'
    brew update &>/dev/null
    msg 'Upgrading and removing outdated formulae...'
    brew upgrade &>/dev/null
  fi
  collect_paths "$(brew --cache)"
  msg 'Cleaning up Homebrew Cache...'
  if [ -z "$dry_run" ]; then
    brew cleanup -s &>/dev/null
    remove_paths
    brew tap --repair &>/dev/null
  else
    remove_paths
  fi
fi

if type "gem" &>/dev/null; then  # TODO add count_dry
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up any old versions of gems'
    gem cleanup &>/dev/null
  fi
fi

if type "docker" &>/dev/null; then  # TODO add count_dry
  if [ -z "$dry_run" ]; then
    if ! docker ps >/dev/null 2>&1; then
      close_docker=true
      open --background -a Docker
    fi
    msg 'Cleaning up Docker'
    docker system prune -af &>/dev/null
    if [ "$close_docker" = true ]; then
      killall Docker
    fi
  fi
fi

if [ "$PYENV_VIRTUALENV_CACHE_PATH" ]; then
  collect_paths "$PYENV_VIRTUALENV_CACHE_PATH"
  msg 'Removing Pyenv-VirtualEnv Cache...'
  remove_paths
fi

if type "npm" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up npm cache...'
    npm cache clean --force &>/dev/null
  else
    collect_paths ~/.npm/*
  fi
fi

if type "yarn" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up Yarn Cache...'
    yarn cache clean --force &>/dev/null
  else
    collect_paths ~/Library/Caches/yarn
  fi
fi

if type "pnpm" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up pnpm Cache...'
    pnpm store prune &>/dev/null
  else
    collect_paths ~/.pnpm-store/*
  fi
fi

if type "pod" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Cleaning up Pod Cache...'
    pod cache clean --all &>/dev/null
  else
    collect_paths ~/Library/Caches/CocoaPods
  fi
fi

if type "go" &>/dev/null; then
  if [ -z "$dry_run" ]; then
    msg 'Clearing Go module cache...'
    go clean -modcache &>/dev/null
  else
    if [ -n "$GOPATH" ]; then
      collect_paths "$GOPATH/pkg/mod"
    else
      collect_paths ~/go/pkg/mod
    fi
  fi
fi

# Deletes all Microsoft Teams Caches and resets it to default - can fix also some performance issues
# -Astro
if [ -d ~/Library/Application\ Support/Microsoft/Teams ]; then
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/IndexedDB
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Application\ Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Code\ Cache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/blob_storage
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/databases
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/gpucache
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/Local\ Storage
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/tmp
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/*logs*.txt
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/watchdog
  collect_paths ~/Library/Application\ Support/Microsoft/Teams/*watchdog*.json
  msg 'Deleting Microsoft Teams logs and caches...'
  remove_paths
fi

# Deletes Poetry cache
if [ -d ~/Library/Caches/pypoetry ]; then
  collect_paths ~/Library/Caches/pypoetry
  msg 'Deleting Poetry cache...'
  remove_paths
fi

# Removes Java heap dumps
collect_paths ~/*.hprof
msg 'Deleting Java heap dumps...'
remove_paths

if [ -z "$dry_run" ]; then
  msg 'Cleaning up DNS cache...'
  dscacheutil -flushcache &>/dev/null
  killall -HUP mDNSResponder &>/dev/null
fi

if [ -z "$dry_run" ]; then
  msg 'Purging inactive memory...'
  purge &>/dev/null
fi

# Disables extended regex
shopt -u extglob

if [ -z "$dry_run" ]; then
  msg "${GREEN}Success!${NOFORMAT}"

  newAvailable=$(df / | tail -1 | awk '{print $4}')
  count=$((newAvailable - oldAvailable))
  bytesToHuman $count
  cleanup
else
  count_dry
  unset dry_run
  bytesToHuman "$dry_results"
  msg "Continue? [enter]"
  read -r -s -n 1 clean_dry_run
  if [[ $clean_dry_run = "" ]]; then
    if [ "$update" = true ]; then
      exec "$0" --update
    else
      exec "$0"
    fi
  fi
  cleanup
fi
