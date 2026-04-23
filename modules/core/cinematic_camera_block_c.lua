local CINEMATIC_CAMERA_CONTROLS = {
    7,   -- INPUT_CINEMATIC_SLOWMO
    80,  -- INPUT_VEH_CIN_CAM
    95,  -- INPUT_VEH_CINEMATIC_UD
    96,  -- INPUT_VEH_CINEMATIC_UP_ONLY
    97,  -- INPUT_VEH_CINEMATIC_DOWN_ONLY
    98,  -- INPUT_VEH_CINEMATIC_LR
}

CreateThread(function()
    while true do
        for group = 0, 2 do
            for _, control in ipairs(CINEMATIC_CAMERA_CONTROLS) do
                DisableControlAction(group, control, true)
            end
        end
        Wait(0)
    end
end)