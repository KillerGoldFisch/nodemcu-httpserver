-- Begin WiFi configuration

local wifiConfig = {}

-- wifi.STATION         -- station: join a WiFi network
-- wifi.SOFTAP          -- access point: create a WiFi network
-- wifi.wifi.STATIONAP  -- both station and access point
wifiConfig.mode = wifi.STATIONAP  -- both station and access point

wifiConfig.accessPointConfig = {}
wifiConfig.accessPointConfig.ssid = "ESP-"..mcu.chipid()   -- Name of the SSID you want to create
wifiConfig.accessPointConfig.pwd = "ESP-"..mcu.chipid()    -- WiFi password - at least 8 characters

wifiConfig.accessPointIpConfig = {}
wifiConfig.accessPointIpConfig.ip = "192.168.111.1"
wifiConfig.accessPointIpConfig.netmask = "255.255.255.0"
wifiConfig.accessPointIpConfig.gateway = "192.168.111.1"

wifiConfig.stationPointConfig = {}
wifiConfig.stationPointConfig.ssid = "d-_-b"        -- Name of the WiFi network you want to join
wifiConfig.stationPointConfig.pwd =  "9a4bc9a4"                -- Password for the WiFi network

-- Tell the chip to connect to the access point

--wifi.setmode(wifiConfig.mode)
--print('set (mode='..wifi.getmode()..')')

if (wifiConfig.mode == wifi.SOFTAP) or (wifiConfig.mode == wifi.STATIONAP) then
    --print('AP MAC: ',wifi.ap.getmac())
    --wifi.ap.config(wifiConfig.accessPointConfig)
    wifi.startap(wifiConfig.accessPointConfig)
    print('AP IP: ',wifi.ap.getip())
end
if (wifiConfig.mode == wifi.STATION) or (wifiConfig.mode == wifi.STATIONAP) then
    --print('Client MAC: ',wifi.sta.getmac())
    --wifi.sta.config(wifiConfig.stationPointConfig.ssid, wifiConfig.stationPointConfig.pwd, 1)
    wifi.startsta(wifiConfig.stationPointConfig)
end

print('chip: ',mcu.chipid())
print('heap: ',mcu.mem())

--wifiConfig = nil
collectgarbage()

-- End WiFi configuration

-- Compile server code and remove original .lua files.
-- This only happens the first time afer the .lua files are uploaded.

local compileAndRemoveIfNeeded = function(f)
   if file.open(f) then
      file.close()
      print('Compiling:', f)
      file.compile(f)
      file.remove(f)
      collectgarbage()
   end
end

--local serverFiles = {'httpserver.lua', 'httpserver-basicauth.lua', 'httpserver-conf.lua', 'httpserver-b64decode.lua', 'httpserver-request.lua', 'httpserver-static.lua', 'httpserver-header.lua', 'httpserver-error.lua'}
--for i, f in ipairs(serverFiles) do compileAndRemoveIfNeeded(f) end

compileAndRemoveIfNeeded = nil
serverFiles = nil
collectgarbage()

-- Connect to the WiFi access point.
-- Once the device is connected, you may start the HTTP server.

if (wifiConfig.mode == wifi.STATION) or (wifiConfig.mode == wifi.STATIONAP) then
    local joinCounter = 0
    local joinMaxAttempts = 10
    tmr.start(0, 3000, function()
       local ip = wifi.sta.getip()
       if (ip == nil or ip == "0.0.0.0") and joinCounter < joinMaxAttempts then
          print('Connecting to WiFi Access Point ...')
          joinCounter = joinCounter +1
       else
          if joinCounter == joinMaxAttempts then
             print('Failed to connect to WiFi Access Point.')
          else
             print('IP: ',ip)
          end
          tmr.stop(0)
          joinCounter = nil
          joinMaxAttempts = nil
          collectgarbage()
       end
    end)
end

-- Uncomment to automatically start the server in port 80
if (not not wifi.sta.getip()) or (not not wifi.ap.getip()) then
    dofile("httpserver.lc")(80)    
end


