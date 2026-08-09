@echo off
REM RuView / wifi-densepose sensing server launcher.
REM
REM Serves the pose/vitals web UI on 8774 and the sensing WebSocket on 8775,
REM both allocated from ~/.claude/port-registry.md. The binary's own defaults
REM (8080 HTTP, 8765 WS) are outside the pool, so both are pinned here.
REM Listens for ADR-018 CSI frames on UDP 5005 from the ESP32-S3 node.
REM
REM --no-edge-registry suppresses the default startup fetch of
REM storage.googleapis.com/cognitum-apps/app-registry.json; nothing in a local
REM hardware trial needs it. Drop the flag if you want the module registry.
REM
REM Extra args are forwarded, so overrides work:
REM   run.cmd --source simulate           (offline demo, no hardware)
REM   run.cmd --model path\to\model.rvf   (real inference instead of heuristics)
REM   run.cmd --bind-addr 0.0.0.0         (expose on the LAN; loopback by default)

setlocal
set "ROOT=%~dp0"

REM Multistatic fusion guard (#1049). The published 60 ms default assumes a real
REM ADR-029 TDM slot schedule, but tdm_slot/tdm_nodes are parsed and validated in
REM the firmware's nvs_config.c and consumed nowhere else, so no slot gating
REM exists in the capture path. Two independently-clocked boards synced only by
REM the 100 ms ESP-NOW beacon drift 10-150 ms; measured spread on this pair is
REM 61-140 ms, which trips the default and makes every fusion cycle fail. Lift
REM the hard guard past the measured spread, per the upstream escape hatch.
REM Remove these two lines if firmware-side TDM ever lands.
set "WDP_GUARD_INTERVAL_US=200000"
set "WDP_SOFT_GUARD_US=100000"

REM Bench layout in metres, as id:x,y,z. x is left/right and z is depth toward
REM the viewer; y is carried for fusion geometry but ignored by the renderer,
REM which maps position[0] to scene X and position[2] to scene Z. Node 3 sits
REM 0.4 m forward of the node 1 / node 2 baseline, which keeps the array a true
REM triangle -- three collinear nodes are degenerate for resolving position off
REM the axis. Re-measure and edit these if the boards move.
REM   node1 left (-0.6), node2 right (+0.6), node3 middle/forward (0, +0.4)
set "SENSING_NODE_POSITIONS=1:-0.6,0,0;2:0.6,0,0;3:0,0,0.4"
set "EXE=%ROOT%v2\target\release\sensing-server.exe"
if not exist "%EXE%" set "EXE=%ROOT%v2\target\debug\sensing-server.exe"

if not exist "%EXE%" (
  echo.
  echo [run.cmd] sensing-server binary not found.
  echo.
  echo Build it first:
  echo     cd v2 ^&^& cargo build -p wifi-densepose-sensing-server
  echo.
  echo For an optimized build ^(recommended for live CSI^):
  echo     cd v2 ^&^& cargo build --release -p wifi-densepose-sensing-server
  echo.
  pause
  exit /b 1
)

echo [run.cmd] %EXE%
echo [run.cmd] UI   -^> http://localhost:8774/ui/index.html
echo [run.cmd] WS   -^> ws://localhost:8775/ws/sensing
echo [run.cmd] CSI  -^> UDP 5005 ^(inbound rule required; see CLAUDE.md notes^)
echo.
REM ui/services/sensing.service.js derives the WS port from the HTTP port via a
REM lookup table that only knows 3000-^>3001 and 8080-^>8765. On 8774 it falls
REM through to ws://localhost:8774, which is wrong, so the pages that stream
REM sensing data need the ?ws= override documented in ui/viz.html.
echo [run.cmd] 3D viz ^(needs the ?ws= override, and unpkg.com for three.js^):
echo [run.cmd]   http://localhost:8774/ui/viz.html?ws=ws://localhost:8775/ws/sensing
echo.

REM --ui-path is passed explicitly: the binary's default is "../ui", which is
REM relative to the CWD and resolves outside the repo when launched from root.
"%EXE%" --http-port 8774 --ws-port 8775 --source auto --no-edge-registry ^
        --ui-path "%ROOT%ui" %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo.
  echo [run.cmd] sensing-server exited with code %RC%.
  echo If the UDP bind failed, check nothing else holds port 5005:
  echo     Get-NetUDPEndpoint -LocalPort 5005
  echo.
  pause
)

exit /b %RC%
