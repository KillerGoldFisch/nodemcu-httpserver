return function (connection, args)
    local v = adc.read(0)
    connection:send("HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nCache-Control: private, no-store\r\n\r\n")
    connection:send('{"value":'..v..'}')
end
