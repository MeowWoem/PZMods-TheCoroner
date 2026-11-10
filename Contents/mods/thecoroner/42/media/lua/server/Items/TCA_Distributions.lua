TCA = TCA or {};
TCA.Distributions = TCA.Distributions or {};

local D = TCA.Distributions;

D.ENTRIES = {
    { list = "MorgueTools", item = "TCA.BoneSaw", weight = 8 },
    { list = "MorgueTools", item = "TCA.BoneSawOscillating", weight = 4 },
    { list = "MorgueTools", item = "TCA.Thermometer", weight = 10 },
    { list = "MedicalStorageTools", item = "TCA.BoneSaw", weight = 2 },
    { list = "MedicalStorageTools", item = "TCA.BoneSawOscillating", weight = 1 },
    { list = "MedicalStorageTools", item = "TCA.Thermometer", weight = 4 },
    { list = "MedicalClinicTools", item = "TCA.Thermometer", weight = 4 },
    { list = "DoctorTools", item = "TCA.Thermometer", weight = 4 },
    { list = "NurseTools", item = "TCA.Thermometer", weight = 4 },
    { list = "TestingLab", item = "TCA.Thermometer", weight = 4 },
    { list = "TestingLab", item = "TCA.BoneSaw", weight = 1 },
    { list = "UniversityStorageScience", item = "TCA.Thermometer", weight = 2 },
    { list = "UniversityStorageScience", item = "TCA.BoneSaw", weight = 1 },
    { list = "ArmyStorageMedical", item = "TCA.BoneSaw", weight = 2 },
};

D.ROOM_ENTRIES = {
    { room = "all", container = "coffin", item = "TCA.HumanBone", weight = 6 },
    { room = "all", container = "coffin", item = "TCA.HumanBone", weight = 4 },
    { room = "all", container = "coffin", item = "TCA.HumanBone", weight = 2 },
};

function D.addEntry(entry)
    if not ProceduralDistributions or not ProceduralDistributions.list then
        return;
    end
    local dist = ProceduralDistributions.list[entry.list];
    if not dist or not dist.items then
        print("TCA: distribution list not found: " .. tostring(entry.list));
        return;
    end
    table.insert(dist.items, entry.item);
    table.insert(dist.items, entry.weight);
end

function D.addRoomEntry(entry)
    if not SuburbsDistributions then
        return;
    end
    local room = SuburbsDistributions[entry.room];
    local container = room and room[entry.container];
    if not container or not container.items then
        print("TCA: distribution container not found: " .. tostring(entry.room) .. "." .. tostring(entry.container));
        return;
    end
    table.insert(container.items, entry.item);
    table.insert(container.items, entry.weight);
end

function D.apply()
    if D.applied then
        return;
    end
    D.applied = true;
    for i = 1, #D.ENTRIES do
        D.addEntry(D.ENTRIES[i]);
    end
    for i = 1, #D.ROOM_ENTRIES do
        D.addRoomEntry(D.ROOM_ENTRIES[i]);
    end
end

Events.OnPreDistributionMerge.Add(D.apply);
