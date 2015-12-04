-- httpserver
-- Author: Marcos Kirsch

-- Starts web server in the specified port.
return function (port)

      local allowStatic = {GET=true, HEAD=true, POST=false, PUT=false, DELETE=false, TRACE=false, OPTIONS=false, CONNECT=false, PATCH=false}

      local function onConnection(connection, ip, port) 

         -- This variable holds the thread used for sending data back to the user.
         -- We do it in a separate thread because we need to yield when sending lots
         -- of data in order to avoid overflowing the mcu's buffer.
         --local connectionThread
         
         print("connecion from ", ip)
      end

      --          __             __  _____                 _            
      --    _____/ /_____ ______/ /_/ ___/___  ______   __(_)___  ____ _
      --   / ___/ __/ __ `/ ___/ __/\__ \/ _ \/ ___/ | / / / __ \/ __ `/
      --  (__  ) /_/ /_/ / /  / /_ ___/ /  __/ /   | |/ / / / / / /_/ / 
      -- /____/\__/\__,_/_/   \__//____/\___/_/    |___/_/_/ /_/\__, /  
      --                                                       /____/   

      local function startServing(fileServeFunction, connection, req, args) 
            local bufferedConnection = {}
            --connectionThread = coroutine.create(function(fileServeFunction, bconnection, req, args)
            --      fileServeFunction(bconnection, req, args)
            --      if not bconnection:flush() then
            --            connection:close()
            --            connectionThread = nil
            --      end
            --end)
            function bufferedConnection:flush() 
                  if self.size > 0 then
                        net.send(connection,table.concat(self.data, ""))
                        --connection:send(table.concat(self.data, ""))
                        self.data = {}
                        self.size = 0    
                        return true
                  end
                  return false
            end
            function bufferedConnection:send(payload) 
                  local l = payload:len()
                  if l + self.size > 1000 then
                        if self:flush() then
                              --coroutine.yield()          
                        end
                  end
                  if l > 800 then
                        net.send(connection, payload)
                        --connection:send(payload)
                        --coroutine.yield()
                  else
                        table.insert(self.data, payload)
                        self.size = self.size + l
                  end
            end
            bufferedConnection.size = 0
            bufferedConnection.data = {}
            
            --local status, err = coroutine.resume(connectionThread, fileServeFunction, bufferedConnection, req, args)
            --if not status then
            --      print(err)
            --end
            
            -- TODO: When "coroutine" are implemented, use them intead!
            fileServeFunction(bufferedConnection, req, args)
            if not bufferedConnection:flush() then
                  connection:close()
                  connectionThread = nil
            end
      end

      --                ____                             __ 
      --   ____  ____  / __ \___  ____ ___  _____  _____/ /_
      --  / __ \/ __ \/ /_/ / _ \/ __ `/ / / / _ \/ ___/ __/
      -- / /_/ / / / / _, _/  __/ /_/ / /_/ /  __(__  ) /_  
      -- \____/_/ /_/_/ |_|\___/\__, /\__,_/\___/____/\__/  
      --                          /_/                       

      local function onRequest(connection, req)
            print("onRequest")
            collectgarbage()
            local method = req.method
            local uri = req.uri
            local fileServeFunction = nil
            
            print("Method: " .. method);
            
            if #(uri.file) > 32 then
                  -- wifimcu-firmware cannot handle long filenames.
                  uri.args = {code = 400, errorString = "Bad Request"}
                  fileServeFunction = dofile("httpserver-error.lc")
            else
                  local fileExists = file.open(uri.file, "r")
                  file.close()
            
                  if not fileExists then
                  -- gzip check
                  fileExists = file.open(uri.file .. ".gz", "r")
                  file.close()
      
                  if fileExists then
                        print("gzip variant exists, serving that one")
                        uri.file = uri.file .. ".gz"
                        uri.isGzipped = true
                  end
                  end
      
                  if not fileExists then
                  uri.args = {code = 404, errorString = "Not Found"}
                  fileServeFunction = dofile("httpserver-error.lc")
                  elseif uri.isScript then
                  fileServeFunction = dofile(uri.file)
                  else
                  if allowStatic[method] then
                        uri.args = {file = uri.file, ext = uri.ext, gzipped = uri.isGzipped}
                        fileServeFunction = dofile("httpserver-static.lc")
                  else
                        uri.args = {code = 405, errorString = "Method not supported"}
                        fileServeFunction = dofile("httpserver-error.lc")
                  end
                  end
            end
            startServing(fileServeFunction, connection, req, uri.args)
      end

      --                ____                 _          
      --   ____  ____  / __ \___  ________  (_)   _____ 
      --  / __ \/ __ \/ /_/ / _ \/ ___/ _ \/ / | / / _ \
      -- / /_/ / / / / _, _/  __/ /__/  __/ /| |/ /  __/
      -- \____/_/ /_/_/ |_|\___/\___/\___/_/ |___/\___/ 
      --                                          

      local function onReceive(connection, payload)
            print("onReceive:", payload)
            collectgarbage()
            local conf = dofile("httpserver-conf.lc")
            local auth
            local user = "Anonymous"
      		
            -- parse payload and decide what to serve.

            local req = dofile("httpserver-request.lc")(payload)
            print("Requested URI: " .. req.request)
            if conf.auth.enabled then
                  auth = dofile("httpserver-basicauth.lc")
                  user = auth.authenticate(payload) -- authenticate returns nil on failed auth
            end
      
            if user and req.methodIsValid and (req.method == "GET" or req.method == "POST" or req.method == "PUT") then
                  onRequest(connection, req)
            else
                  local args = {}
                  local fileServeFunction = dofile("httpserver-error.lc")
                  if not user then
                  args = {code = 401, errorString = "Not Authorized", headers = {auth.authErrorHeader()}}
                  elseif req.methodIsValid then
                  args = {code = 501, errorString = "Not Implemented"}
                  else
                  args = {code = 400, errorString = "Bad Request"}
                  end
                  startServing(fileServeFunction, connection, req, args)
            end
      end

      --               _____            __ 
      --   ____  ____ / ___/___  ____  / /_
      --  / __ \/ __ \\__ \/ _ \/ __ \/ __/
      -- / /_/ / / / /__/ /  __/ / / / /_  
      -- \____/_/ /_/____/\___/_/ /_/\__/  
      --                                   

      local function onSent(connection, payload)
            -- collectgarbage()
            -- if connectionThread then
            --    local connectionThreadStatus = coroutine.status(connectionThread) 
            --    if connectionThreadStatus == "suspended" then
            --       -- Not finished sending file, resume.
            --       local status, err = coroutine.resume(connectionThread)
            --       if not status then
            --          print(err)
            --       end
            --    elseif connectionThreadStatus == "dead" then
            --       -- We're done sending file.
            --       connection:close()
            --       connectionThread = nil
            --    end
            -- end
      end
      
      -- Event-Listener
      
      -- connection:on("disconnect",function(c) end)
      -- connection:on("receive", onReceive)
      -- connection:on("sent", onSent)

      
      local sk = net.new(net.TCP, net.SERVER)
      net.start(sk, port)
      
      net.on(sk,"accept", onConnection)
      net.on(sk,"disconnect",function(c) end)
      net.on(sk,"sent",function(con) end)
      net.on(sk,"receive", onReceive)
      
      
      -- false and nil evaluate as false
      --local ip = wifi.sta.getip()
      --if not ip then ip = wifi.ap.getip() end
      --print("nodemcu-httpserver running at http://" .. ip .. ":" ..  port)
      --return s
      --return sk
end
