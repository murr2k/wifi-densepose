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
echo [run.cmd] UI  -^> http://localhost:8774
echo [run.cmd] WS  -^> ws://localhost:8775
echo [run.cmd] CSI -^> UDP 5005 ^(inbound rule required; see README notes^)
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
