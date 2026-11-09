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
, xprop
}:
let
  wine = wineWow64Packages.stable;

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
      coreutils util-linux findutils gnused gnugrep xprop
    ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/mtgo"
      export WINEPREFIX="$data/prefix"
      export WINEARCH=win64
      export WINEDEBUG="''${WINEDEBUG:--all}"
      export W_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/winetricks"
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

      if [ ! -e "$bootstrapped" ]; then
        echo "Setting up MTGO wine prefix in $WINEPREFIX (takes a while)..." >&2
        ln -sf ${powerPointViewer} "$W_CACHE/PowerPointViewer/PowerPointViewer.exe"
        # skip the Mono/Gecko install prompts; dotnet48 replaces Mono anyway
        WINEDLLOVERRIDES="mscoree=;mshtml=" wineboot -i
        winetricks -q corefonts calibri tahoma d3dcompiler_47
        # dotnet48's installer hangs on multiple cores
        taskset -c 0 winetricks -f -q dotnet48
        winetricks -q win7 renderer=gdi gdiplus=builtin \
          sound=disabled winegstreamer=disabled wmp=disabled
        wineboot -s

        # keep MTGO's Documents (replays, deck exports) outside the prefix
        docs="$WINEPREFIX/drive_c/users/$USER/Documents"
        rm -rf "$docs"
        ln -s "$data/files" "$docs"

        touch "$bootstrapped"
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

      # with an audio driver loaded, MTGO's startup chime throws an unhandled
      # InvalidCastException (ISimpleAudioVolume); without one it carries on
      export WINEDLLOVERRIDES="winepulse.drv=d;winealsa.drv=d;wineoss.drv=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"

      # MTGO loads on its UI thread, which is also where wine answers GNOME's
      # _NET_WM_PING, so GNOME offers to kill it while it loads. Withdraw the
      # ping from MTGO's windows as they appear and GNOME stops checking them.
      unping_mtgo_windows() {
        local w
        for w in $(xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]*'); do
          xprop -id "$w" WM_CLASS 2>/dev/null | grep -q '"mtgo.exe"' || continue
          xprop -id "$w" WM_PROTOCOLS 2>/dev/null | grep -q _NET_WM_PING || continue
          xprop -id "$w" -f WM_PROTOCOLS 32a \
            -set WM_PROTOCOLS WM_DELETE_WINDOW,WM_TAKE_FOCUS 2>/dev/null || true
        done
      }
      if [ -n "''${DISPLAY:-}" ]; then
        exec {spy}< <(xprop -root -spy _NET_CLIENT_LIST)
        spy_pid=$!
        while read -r _ <&"$spy"; do unping_mtgo_windows; done &
        unping_pid=$!
        trap 'kill "$spy_pid" "$unping_pid" 2>/dev/null || true' EXIT
      fi

      cd "$WINEPREFIX/drive_c"
      # Docker and Lutris both cap MTGO at 4 CPUs
      taskset -c 0-3 wine 'C:\mtgo-setup.exe'
      # setup.exe hands off to the ClickOnce client; stay up until it exits
      wineserver -w
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
