--luacheck: no max line length
--*****************************************************************
-- Inside of this script, you will find helper functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

local funcs = {}
-- Providing standard JSON functions
funcs.json = require('Communication/LiveConnect/helper/Json')

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

-- Function to create a list from table
--@createStringListBySize(size:int):string
local function createStringListBySize(size)
  local list = "["
  if size >= 1 then
    list = list .. '"' .. tostring(1) .. '"'
  end
  if size >= 2 then
    for i=2, size do
      list = list .. ', ' .. '"' .. tostring(i) .. '"'
    end
  end
  list = list .. "]"
  return list
end
funcs.createStringListBySize = createStringListBySize

-- Function to convert a table into a Container object
--@convertTable2Container(data:table):Container
local function convertTable2Container(data)
  local cont = Container.create()

  for key, value in pairs(data) do
    if type(value) == 'table' then
      local subCont = Container.create()
      for subKey, subValue in pairs(value) do
        if type(subValue) == 'table' then
          local sub2Cont = Container.create()
          for sub2Key, sub2Value in pairs(subValue) do

            if type(sub2Value) == 'table' then
              local sub3Cont = Container.create()
              for sub3Key, sub3Value in pairs(sub2Value) do

                if type(sub3Value) == 'table' then
                  local sub4Cont = Container.create()
                  for sub4Key, sub4Value in pairs(sub3Value) do
                    sub4Cont:add(sub4Key, sub4Value, nil)
                  end
                  sub3Cont:add(sub3Key, sub4Cont, nil)
                else
                  sub3Cont:add(sub3Key, sub3Value, nil)
                end
              end
              sub2Cont:add(sub2Key, sub3Cont, nil)
            else
              sub2Cont:add(sub2Key, sub2Value, nil)
            end
          end
          subCont:add(subKey, sub2Cont, nil)
        else
          subCont:add(subKey, subValue, nil)
        end
      end
      cont:add(key, subCont, nil)
    else
      cont:add(key, value, nil)
    end
  end
  return cont
end
funcs.convertTable2Container = convertTable2Container

-- Function to convert a Container into a table
--@convertContainer2Table(cont:Container):table
local function convertContainer2Table(cont)
  local data = {}
  local containerList = Container.list(cont)
  local containerCheck = false
  
  if tonumber(containerList[1]) then
    containerCheck = true
  end

  for i=1, #containerList do
    local subContainer
    if containerCheck then
      subContainer = Container.get(cont, tostring(i) .. '.00')
    else
      subContainer = Container.get(cont, containerList[i])
    end
    if type(subContainer) == 'userdata' then
      if Object.getType(subContainer) == "Container" then
        local subTable = {}
        local subContainerList = Container.list(subContainer)
        local subContainerCheck = false
        if tonumber(subContainerList[1]) then
          subContainerCheck = true
        end

        for j = 1, #subContainerList do
          local sub2Container
          if subContainerCheck then
            sub2Container = Container.get(subContainer, tostring(j).. '.00')
          else
            sub2Container = Container.get(subContainer, subContainerList[j])
          end
          if type(sub2Container) == 'userdata' then
            if Object.getType(sub2Container) == "Container" then
              local sub2Table = {}
              local sub2ContainerList = Container.list(sub2Container)
              local sub2ContainerCheck = false
              if tonumber(sub2ContainerList[1]) then
                sub2ContainerCheck = true
              end

              for k = 1, #sub2ContainerList do
                local sub3Container --new
                if sub2ContainerCheck then
                  sub3Container = Container.get(sub2Container, tostring(k).. '.00')
                else
                  sub3Container = Container.get(sub2Container, sub2ContainerList[k])
                end
-------------------------------
                if type(sub3Container) == 'userdata' then
                  if Object.getType(sub3Container) == "Container" then
                    local sub3Table = {}
                    local sub3ContainerList = Container.list(sub3Container)
                    local sub3ContainerCheck = false
                    if tonumber(sub3ContainerList[1]) then
                      sub3ContainerCheck = true
                    end

                    for l = 1, #sub3ContainerList do
                      local sub4Container --new
                      if sub3ContainerCheck then
                        sub4Container = Container.get(sub3Container, tostring(l).. '.00')
                      else
                        sub4Container = Container.get(sub3Container, sub3ContainerList[l])
                      end
-------------------------------
                      if type(sub4Container) == 'userdata' then
                        if Object.getType(sub4Container) == "Container" then
                          local sub4Table = {}
                          local sub4ContainerList = Container.list(sub4Container)
                          local sub4ContainerCheck = false
                          if tonumber(sub4ContainerList[1]) then
                            sub4ContainerCheck = true
                          end

                          for m = 1, #sub4ContainerList do
                            if sub4ContainerCheck then
                              local temp = Container.get(sub4Container, tostring(m) .. '.00')
                              table.insert(sub4Table, Container.get(sub4Container, tostring(m) .. '.00'))
                            else
                              local temp = Container.get(sub4Container, sub4ContainerList[m])
                              sub4Table[sub4ContainerList[m]] = Container.get(sub4Container, sub4ContainerList[m])
                            end
                          end
-------------------------------
                          if sub3ContainerCheck then
                            table.insert(sub3Table, sub4Table)
                          else
                            sub3Table[sub3ContainerList[l]] = sub4Table
                          end
                        else
                          if sub3ContainerCheck then
                            table.insert(sub3Table, sub4Container)
                          else
                            sub3Table[sub3ContainerList[l]] = sub4Container
                          end
                        end
                      else
                        if sub3ContainerCheck then
                          table.insert(sub3Table, sub4Container)
                        else
                          sub3Table[sub3ContainerList[l]] = sub4Container
                        end
                        
                      end
                    end
-----------------------------
                    if sub2ContainerCheck then
                      table.insert(sub2Table, sub3Table)
                    else
                      sub2Table[sub2ContainerList[k]] = sub3Table
                    end
                  else
                    if sub2ContainerCheck then
                      table.insert(sub2Table, sub3Container)
                    else
                      sub2Table[sub2ContainerList[k]] = sub3Container
                    end
                  end
                else
                  if sub2ContainerCheck then
                    table.insert(sub2Table, sub3Container)
                  else
                    sub2Table[sub2ContainerList[k]] = sub3Container
                  end
                end
              end
------------------------------
              if subContainerCheck then
                table.insert(subTable, sub2Table)
              else
                subTable[subContainerList[j]] = sub2Table
              end
            else
              if subContainerCheck then
                table.insert(subTable, sub2Container)
              else
                subTable[subContainerList[j]] = sub2Container
              end
            end
          else
            if subContainerCheck then
              table.insert(subTable, sub2Container)
            else
              subTable[subContainerList[j]] = sub2Container
            end
          end
        end
        if containerCheck then
          table.insert(data, subTable)
        else
          data[containerList[i]] = subTable
        end
      else
        if containerCheck then
          table.insert(data, subContainer)
        else
          data[containerList[i]] = subContainer
        end
      end
    else
      if containerCheck then
        table.insert(data, subContainer)
      else
        data[containerList[i]] = subContainer
      end
    end
  end
  return data
end
funcs.convertContainer2Table = convertContainer2Table

-- Function to get content list
--@createContentList(data:table):string
local function createContentList(data)
  local sortedTable = {}
  for key, _ in pairs(data) do
    table.insert(sortedTable, key)
  end
  table.sort(sortedTable)
  return table.concat(sortedTable, ',')
end
funcs.createContentList = createContentList

-- Function to get content list
--@createContentList(data:table):string
local function createJsonList(data)
  local sortedTable = {}
  for key, _ in pairs(data) do
    table.insert(sortedTable, key)
  end
  table.sort(sortedTable)
  return funcs.json.encode(sortedTable)
end
funcs.createJsonList = createJsonList
-- Function to create a list from table
--@createStringListBySimpleTable(content:table):string
local function createStringListBySimpleTable(content)
  local list = "["
  if #content >= 1 then
    list = list .. '"' .. content[1] .. '"'
  end
  if #content >= 2 then
    for i=2, #content do
      list = list .. ', ' .. '"' .. content[i] .. '"'
    end
  end
  list = list .. "]"
  return list
end
funcs.createStringListBySimpleTable = createStringListBySimpleTable
return funcs

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************