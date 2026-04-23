RegisterNUICallback('phone:stats:getData', function(_, cb)
    local data = lib.callback.await('streetkings:stats:getData', false)
    cb(data)
end)