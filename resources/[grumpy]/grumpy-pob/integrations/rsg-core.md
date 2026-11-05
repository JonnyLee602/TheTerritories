# rsg-core patch (grumpy-pob)

Each business gets its own multi-job (`pob_<id>`). rsg-core's job registry (`multijob_jobs`) only has admin-menu and
start-up ways to add a job definition, so this patch exposes two server exports that wrap the registry. With it, a new
business can hire straight away. Without it grumpy-pob writes the row itself and **hiring into a new business only
works after the next server restart** (a warning is printed).
This is a local change to an RSG resource: re-apply after updating rsg-core, or offer it upstream.

## server/multijob/server.lua

Find the `local api = {` table (near the end, the one with `AddPlayerJob = AddJob,`) and add two entries:

```lua
local api = {
    AddPlayerJob = AddJob,
    RemovePlayerJob = RemoveJob,
    GetPlayerJobs = GetJobs,
    HasPlayerJob = HasJob,
    CanTakePlayerJob = CanTakeJob,
    GetPlayerJobCount = ExportGetJobCount,
    GetJobDefinition = function(name) return JobRegistry.Get(name) end,
    GetJobDefinitions = function() return JobRegistry.All() end,
    -- grumpy-pob: create/update and delete job definitions from another resource (validated by the registry)
    SaveJobDefinition = function(input)
        local name = type(input) == 'table' and type(input.name) == 'string' and input.name:lower() or nil
        return JobRegistry.Save(input, name == nil or JobRegistry.All()[name] == nil)
    end,
    DeleteJobDefinition = function(name) return JobRegistry.Delete(name) end,
}
```

`SaveJobDefinition(input)` returns `def, errKey`. `DeleteJobDefinition(name)` returns `ok, errKey, holders`
(removes the job from every player, online and offline).

## Check it worked
Create a business with `/pob`, then `/jobadmin`: the job `pob_<id>` is listed with the grades from `Config.Grades`.
