{ writeShellApplication
, makeDesktopItem
, runCommand
, symlinkJoin
, fetchurl
, wineWow64Packages
, winetricks
, curl
, cabextract
, coreutils
, util-linux
, findutils
, gnused
, gnugrep
, procps
, zenity
}:
let
  # MTGO's mute check casts an audio session to ISimpleAudioVolume, which
  # wine refused until 11.3 (MR 9756), so its startup chime threw an
  # unhandled InvalidCastException. Its sounds go through Media Foundation's
  # resampler, which wine implements on GStreamer, and only the Full
  # variants build with it. Before each sound it also reads the volume of
  # device 0 with waveOutGetVolume, which wine only answers for open handles;
  # MTGO ignores the error, reads a volume of 0 and stays silent. NAudio then
  # sets the resampler's filter length, which wine stubs out with E_NOTIMPL,
  # and the exception kills the sound queue's playback thread.
  wine = wineWow64Packages.unstableFull.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./winmm-volume-device-id.patch
      ./resampler-half-filter-length.patch
    ];
  });

  # winetricks fetches this from web.archive.org, which is slow and flaky.
  powerPointViewer = fetchurl {
    url = "https://github.com/pauleve/docker-mtgo/releases/download/artifacts/PowerPointViewer.exe";
    hash = "sha256-JJRzVo66eh5PlUmKy6WU4PQuZYGt1N6tcMHfuQiglCM=";
  };

  # Native port of https://github.com/pauleve/docker-mtgo, with crash fixes
  # for wine 11 and tuning from the Lutris installer
  # (https://github.com/darkview224/lutris-mtgo-script).
  mtgo = writeShellApplication {
    name = "mtgo";
    runtimeInputs = [
      wine winetricks curl cabextract
      coreutils util-linux findutils gnused gnugrep procps zenity
    ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/mtgo"
      mkdir -p "$data"

      # Two launches at once (e.g. the desktop icon and a terminal) clobber
      # each other's winetricks temp files and share one wineserver. -o keeps
      # the lock out of wine's processes, which can outlive this script.
      if [ -z "''${MTGO_LOCKED:-}" ]; then
        rc=0
        MTGO_LOCKED=1 flock -n -o -E 75 "$data/.lock" "$0" "$@" || rc=$?
        [ "$rc" -eq 75 ] && echo "MTGO is already running or setting up" >&2
        exit "$rc"
      fi
      export WINEPREFIX="$data/prefix"
      export WINEARCH=win64
      export WINEDEBUG="''${WINEDEBUG:--all}"
      export W_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/winetricks"
      # The Full variants wrap bin/wine in a script, so winetricks can't read
      # its ELF header to tell it's a wow64 build and falls back to wine64,
      # which wow64 builds don't have.
      export WINE64=wine
      setup="$WINEPREFIX/drive_c/mtgo-setup.exe"
      bootstrapped="$WINEPREFIX/.mtgo-bootstrapped"

      usage() {
        echo "Usage: mtgo [--winecfg] [--reset] [--help]"
        echo "  --winecfg  run winecfg before starting MTGO"
        echo "  --reset    delete the wine prefix and set it up again"
      }

      do_winecfg=false
      do_reset=false
      for arg in "$@"; do
        case "$arg" in
          --winecfg) do_winecfg=true ;;
          --reset) do_reset=true ;;
          -h|--help) usage; exit 0 ;;
          *) usage >&2; exit 1 ;;
        esac
      done

      if $do_reset && [ -d "$WINEPREFIX" ]; then
        echo "About to delete $WINEPREFIX. Enter to continue, Ctrl+C to abort." >&2
        read -r
        wineserver -k || true
        rm -rf "$WINEPREFIX"
      fi

      mkdir -p "$data/files" "$W_CACHE/PowerPointViewer"

      # Setup shows a progress window, so launching from the desktop isn't ten
      # silent minutes. It's fed through fd 3, which wine must not inherit:
      # wineserver outlives setup and would hold the window open.
      progress_open=false
      creeper=""
      cancelled="$data/.setup-cancelled"
      progress() {
        $progress_open || return 0
        ( trap "" PIPE; printf '%s\n' "$@" >&3 ) 2>/dev/null || true
      }
      # Steps print nothing to go on, so move the bar from $1 towards $2
      # percent over the $3 seconds they usually take.
      creep() {
        $progress_open || return 0
        (
          trap "" PIPE
          start=$SECONDS
          while sleep 5; do
            pct=$(( $1 + ($2 - $1) * (SECONDS - start) / $3 ))
            [ "$pct" -gt "$2" ] && pct=$2
            printf '%s\n' "$pct" >&3 || exit 0
          done
        ) 2>/dev/null &
        creeper=$!
      }
      stop_creep() {
        if [ -n "$creeper" ]; then kill "$creeper" 2>/dev/null || true; fi
        creeper=""
      }
      step() { stop_creep; progress "$1" "# $2"; echo "$2" >&2; }
      start_progress() {
        [ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ] || return 0
        rm -f "$cancelled"
        fifo="$data/.setup-progress"
        rm -f "$fifo"
        mkfifo "$fifo"
        main=$$
        (
          if ! zenity --progress --title="Magic: The Gathering Online" \
              --text="Setting up Magic Online" --width=440 \
              --auto-close --time-remaining <"$fifo" 2>/dev/null; then
            # Cancel: stop setup and the wine processes it started
            touch "$cancelled"
            for pid in $(pgrep -P "$main"); do
              [ "$pid" = "$BASHPID" ] || kill "$pid" 2>/dev/null || true
            done
            kill "$main" 2>/dev/null || true
            wineserver -k 2>/dev/null || true
          fi
        ) 3>&- &
        exec 3>"$fifo"
        rm -f "$fifo"
        progress_open=true
      }
      setup_exit() {
        stop_creep
        $progress_open || return 0
        exec 3>&-
        if [ ! -e "$bootstrapped" ] && [ ! -e "$cancelled" ]; then
          zenity --error --title="Magic: The Gathering Online" \
            --text="Setting up Magic Online failed. Run mtgo in a terminal to see why." \
            2>/dev/null || true
        fi
        rm -f "$cancelled"
      }

      if [ ! -e "$bootstrapped" ]; then
        trap setup_exit EXIT
        start_progress
        echo "Setting up MTGO wine prefix in $WINEPREFIX (takes a while)..." >&2
        # a prefix whose setup was cut short is started over
        if [ -d "$WINEPREFIX" ]; then
          wineserver -k 3>&- || true
          rm -rf "$WINEPREFIX"
        fi
        ln -sf ${powerPointViewer} "$W_CACHE/PowerPointViewer/PowerPointViewer.exe"

        step 0 "Creating the wine prefix"
        # skip the Mono/Gecko install prompts; dotnet48 replaces Mono anyway
        WINEDLLOVERRIDES="mscoree=;mshtml=" wineboot -i 3>&-

        step 3 "Installing fonts"
        creep 3 12 80
        winetricks -q corefonts calibri tahoma d3dcompiler_47 3>&-

        step 12 "Installing .NET Framework 4.8 (takes several minutes)"
        creep 12 95 540
        # dotnet48's installer hangs on multiple cores
        taskset -c 0 winetricks -f -q dotnet48 3>&-

        step 95 "Configuring wine"
        winetricks -q win7 renderer=gdi gdiplus=builtin sound=pulse wmp=disabled 3>&-
        wineboot -s 3>&-

        # keep MTGO's Documents (replays, deck exports) outside the prefix
        docs="$WINEPREFIX/drive_c/users/$USER/Documents"
        rm -rf "$docs"
        ln -s "$data/files" "$docs"

        touch "$bootstrapped"
        step 100 "Starting Magic Online"
        setup_exit
        trap - EXIT
      fi

      $do_winecfg && { winecfg; wineserver -w; }

      wineboot
      # certificate verification crashes without it (wine 6.19)
      mkdir -p "$WINEPREFIX/drive_c/users/$USER/AppData/LocalLow"

      if [ ! -s "$setup" ]; then
        curl -fL -o "$setup.part" \
          "https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe?v=8"
        mv "$setup.part" "$setup"
      fi

      # stops the collection view from pinning a core and freezing the UI
      # (from the Lutris installer); the config only exists once installed
      find "$WINEPREFIX/drive_c/users" -path '*Apps/2.0*' -iname MTGO.exe.config \
        -exec sed -i -E 's/("(DisableAutomationPeer|PurgeAutomationEvents|DisableStylusInput|DisableTabletDevices)" value=")false/\1true/g' {} +

      # prefixes set up for wine 11.0 have sound and GStreamer turned off
      # (winetricks can't do this here: it runs while wine upgrades the prefix)
      if grep -q '^"Audio"="disabled"' "$WINEPREFIX/user.reg"; then
        wine reg add 'HKCU\Software\Wine\Drivers' /v Audio /d pulse /f
        wine reg delete 'HKCU\Software\Wine\DllOverrides' /v '*winegstreamer' /f || true
        # wine skipped winegstreamer's system32 stubs while it was disabled
        wineboot -u
        wineserver -w
      fi

      cd "$WINEPREFIX/drive_c"
      # MTGO loads on its UI thread, where wine answers GNOME's _NET_WM_PING, so
      # GNOME may offer to kill it while it loads; answer Wait. Don't withdraw
      # the ping: GNOME keeps a window it saw stop responding unfocusable, off
      # the dock and stuck on its workspace until it answers a ping again.
      #
      # Docker and Lutris both cap MTGO at 4 CPUs
      taskset -c 0-3 wine 'C:\mtgo-setup.exe'

      # setup.exe hands off to the ClickOnce client, and dfsvc.exe and .NET's
      # mscorsvw.exe outlive MTGO and keep wine up, so wait on MTGO.exe itself.
      # The first launch downloads the client before it starts, and a client
      # update restarts it, so it has to stay gone for a few seconds.
      mtgo_running() { pgrep -f 'MTGO\.exe' >/dev/null; }
      SECONDS=0
      until mtgo_running; do
        if [ "$SECONDS" -gt 1800 ]; then
          echo "MTGO did not start within 30 minutes" >&2
          wineserver -k
          exit 1
        fi
        sleep 2
      done
      gone=0
      while [ "$gone" -lt 3 ]; do
        if mtgo_running; then gone=0; else gone=$((gone + 1)); fi
        sleep 2
      done
      wineserver -k
    '';
  };

  desktopItem = makeDesktopItem {
    name = "mtgo";
    desktopName = "Magic: The Gathering Online";
    genericName = "Card game";
    exec = "mtgo";
    icon = "mtgo";
    categories = [ "Game" "CardGame" ];
    terminal = false;
    # wine names X11 windows after the executable
    startupWMClass = "mtgo.exe";
  };

  # Extracted from the installed client's MTGO.exe.
  icons = runCommand "mtgo-icons" { } ''
    for size in 16 24 32 48 256; do
      install -Dm644 ${./icons}/$size.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/mtgo.png
    done
  '';
in
symlinkJoin {
  name = "mtgo";
  paths = [ mtgo desktopItem icons ];
  meta = {
    description = "Magic: The Gathering Online under wine";
    homepage = "https://github.com/pauleve/docker-mtgo";
    platforms = [ "x86_64-linux" ];
    mainProgram = "mtgo";
  };
}
