-- SKEvents server state machine
SKEventsServer = {
    dbReady = false,
    lastSubmit = {},
    openRaceLobbies = {},
    lobbyIdBySource = {},
    nextBucketOffset = 0,
    mpVehicleNetIdBySource = {},
}