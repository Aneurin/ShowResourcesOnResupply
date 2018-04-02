ShowResourcesOnResupplyScreen = {}
ShowResourcesOnResupplyScreen.StringIdBase = 76827446

function OnMsg.Autorun()
    -- The only way I can see to hook into opening/closing the resupply dialog to do something in
    -- response is to wrap the global functions that are used
    if not ShowResourcesOnResupplyScreen.OrigResupplyDialogOpen then
        ShowResourcesOnResupplyScreen.OrigResupplyDialogOpen = ResupplyDialogOpen
    end
    if not ShowResourcesOnResupplyScreen.OrigResupplyDialogClose then
        ShowResourcesOnResupplyScreen.OrigResupplyDialogClose = ResupplyDialogClose
    end
    ResupplyDialogOpen = function(...)
        local ret = ShowResourcesOnResupplyScreen.OrigResupplyDialogOpen(...)
        ShowResourcesOnResupplyScreen:SpawnManglerThread()
        return ret
    end
    ResupplyDialogClose = function(...)
        local ret = ShowResourcesOnResupplyScreen.OrigResupplyDialogClose(...)
        ShowResourcesOnResupplyScreen:DeleteManglerThread()
        return ret
    end
end

-- I can't find any way to trigger when the payload list is opened, so instead we're going to watch
-- for it in a loop.
function ShowResourcesOnResupplyScreen:SpawnManglerThread()
    if self.mangler_thread and IsValidThread(self.mangler_thread) then return end
    self.mangler_thread = CreateRealTimeThread(function()
        local resupply, resupply_ui, resupply_content, list
        resupply = GetXDialog("Resupply")
        while true do
            WaitMsg("OnRender")
            if resupply and #resupply.children >= 7 then
                resupply_ui = resupply.children[7]
                if #resupply_ui.children >= 1 then
                    resupply_content = resupply_ui.children[1]
                    if resupply_content.idList then
                        list = resupply_content.idList
                        if #list.children > 1 and list.children[1].context.prop_meta then
                            if list.children[1].context.prop_meta.category == "Payload" then
                                if #list.children[6] > 4 then
                                    -- This means the screen we want is actually up right now, with
                                    -- the element we added, so we can take it easy for a bit. When
                                    -- it closes it will be replaced with a new unmangled list and
                                    -- we will need to start watching it like a hawk again.
                                    Sleep(1000)
                                else
                                    ShowResourcesOnResupplyScreen:MangleList(list)
                                    local OrigDone = list.Done
                                    list.Done = function(...)
                                        ShowResourcesOnResupplyScreen:SpawnManglerThread()
                                        return OrigDone(list, ...)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

function ShowResourcesOnResupplyScreen:DeleteManglerThread()
    if self.mangler_thread and IsValidThread(self.mangler_thread) then
        DeleteThread(self.mangler_thread)
    end
end

function ShowResourcesOnResupplyScreen:MangleList(list)
    local first_row = 6
    local last_row = 11
    -- We happen to know these rows
    if #list.children < last_row then
        -- We're probably on the Space Elevator screen, which doesn't include drones or vehicles
        first_row = first_row - 4
        last_row = last_row - 4
    end
    local texts = {}
    texts[first_row] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<concrete(AvailableConcrete)>", ResourceOverviewObj}}
    texts[first_row + 1] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<metals(AvailableMetals)>", ResourceOverviewObj}}
    texts[first_row + 2] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<food(AvailableFood)>", ResourceOverviewObj}}
    texts[first_row + 3] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<polymers(AvailablePolymers)>", ResourceOverviewObj}}
    texts[first_row + 4] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<machineparts(AvailableMachineParts)>", ResourceOverviewObj}}
    texts[first_row + 5] = T{ShowResourcesOnResupplyScreen.StringIdBase, "<count> in stock",
        count = T{"<electronics(AvailableElectronics)>", ResourceOverviewObj}}

    for i = first_row, last_row do
        -- With the payload controls docked to the right, our right margin is set to their left
        -- margin. This means that it moves whenever their width changes. Undocking the payload
        -- controls and right aligning them leaves them in the same place, but allows our position
        -- to remain fixed.
        if #list.children < i then
            -- Who knows what's up here
            return
        end
        local row = list.children[i]
        row.children[4]:SetDock(false)
        row.children[4]:SetHAlign("right")
        local text = XText:new({
            HAlign = "right",
            Margins = box(0, 0, 180, 0),
            TextColor = RGB(255,255,255),
            RolloverTextColor = RGB(255,255,255),
            TextFont = "HexChoice",
            MinWidth = 50,
            TextVAlign = "center",
            TextHAlign = "right",
        }, row):SetText(texts[i])
    end
end

