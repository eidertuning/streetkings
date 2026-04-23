-- Mission definition loader + lookup helpers

SKMissionDefs = {}

local chapterById = {}
local chapterOrder = {}
local missionsById = {}

---@return nil
local function build()
    chapterById = {}
    chapterOrder = {}
    missionsById = {}

    if type(SKMissions) ~= 'table' or type(SKMissions.chapters) ~= 'table' then
        return
    end

    for _, chapter in ipairs(SKMissions.chapters) do
        assert(type(chapter.id) == 'string' and chapter.id ~= '', 'streetkings: chapter missing id')
        assert(type(chapter.missions) == 'table', ('streetkings: chapter %s missing missions'):format(chapter.id))
        chapterById[chapter.id] = chapter
        chapterOrder[#chapterOrder + 1] = chapter.id
        for index, mission in ipairs(chapter.missions) do
            assert(type(mission.id) == 'string' and mission.id ~= '', ('streetkings: mission in %s missing id'):format(chapter.id))
            assert(type(mission.objectives) == 'table' and #mission.objectives > 0, ('streetkings: mission %s missing objectives'):format(mission.id))
            missionsById[mission.id] = { chapterId = chapter.id, index = index, def = mission }
        end
    end
end

build()

---@return string[]
function SKMissionDefs.listChapters()
    return chapterOrder
end

---@param chapterId string
---@return table|nil
function SKMissionDefs.getChapter(chapterId)
    return chapterById[chapterId]
end

---@param missionId string
---@return table|nil, table|nil, integer|nil
function SKMissionDefs.get(missionId)
    local entry = missionsById[missionId]
    if not entry then return nil, nil, nil end
    return entry.def, chapterById[entry.chapterId], entry.index
end

---@param chapterId string
---@param missionIndex integer
---@return table|nil
function SKMissionDefs.getByIndex(chapterId, missionIndex)
    local chapter = chapterById[chapterId]
    if not chapter or type(missionIndex) ~= 'number' then return nil end
    return chapter.missions[missionIndex]
end

---@param chapterId string
---@param missionIndex integer
---@return string|nil, integer|nil, table|nil
function SKMissionDefs.advance(chapterId, missionIndex)
    local chapter = chapterById[chapterId]
    if not chapter then return nil, nil, nil end
    local nextIndex = missionIndex + 1
    local nextMission = chapter.missions[nextIndex]
    if nextMission then
        return chapterId, nextIndex, nextMission
    end

    local currentChapterPos
    for i, id in ipairs(chapterOrder) do
        if id == chapterId then
            currentChapterPos = i
            break
        end
    end
    if not currentChapterPos then return nil, nil, nil end

    local nextChapterId = chapterOrder[currentChapterPos + 1]
    if not nextChapterId then return nil, nil, nil end

    local nextChapter = chapterById[nextChapterId]
    return nextChapterId, 1, nextChapter.missions[1]
end

---@param missionsDoc SKSaveMissionsDocument
---@return table|nil, string|nil, integer|nil
function SKMissionDefs.getNext(missionsDoc)
    if type(missionsDoc) ~= 'table' then return nil, nil, nil end

    if missionsDoc.chapter == nil or missionsDoc.chapter <= 0 then
        local firstId = chapterOrder[1]
        if not firstId then return nil, nil, nil end
        return chapterById[firstId].missions[1], firstId, 1
    end

    local chapterId = chapterOrder[missionsDoc.chapter]
    if not chapterId then return nil, nil, nil end

    local nextIndex = (missionsDoc.chapterMissionIndex or 0) + 1
    local chapter = chapterById[chapterId]
    local mission = chapter.missions[nextIndex]
    if mission then
        return mission, chapterId, nextIndex
    end

    local nextChapterPos = missionsDoc.chapter + 1
    local nextChapterId = chapterOrder[nextChapterPos]
    if not nextChapterId then return nil, nil, nil end
    return chapterById[nextChapterId].missions[1], nextChapterId, 1
end

---@param chapterId string
---@return integer
function SKMissionDefs.chapterPosition(chapterId)
    for i, id in ipairs(chapterOrder) do
        if id == chapterId then return i end
    end
    return 0
end
