local FV = {}
local indent = 4

--- used for task scheduler

local scheduled = {}

--- RBXScriptConnect of the task scheduler

local schedulerconnect
function FV:ArgsToString(method, args)

	assert(typeof(method) == "string", "string expected, got " .. typeof(method))

	assert(typeof(args) == "table", "table expected, got " .. typeof(args))

	return FV.v2v({ args = args }) .. "\n\n" .. method .. "(unpack(args))"

end



--- Converts a value to variables with the specified index as the variable name (if nil/invalid then the name will be assigned automatically)

--- @param t any[]

--- @return string

function FV:TableToVars(t)

	assert(typeof(t) == "table", "table expected, got " .. typeof(t))

	return FV.v2v(t)

end



--- Converts a value to a variable with the specified `variablename` (if nil/invalid then the name will be assigned automatically)

--- @param value any

--- @return string

function FV:ValueToVar(value, variablename)

	assert(variablename == nil or typeof(variablename) == "string", "string expected, got " .. typeof(variablename))

	if not variablename then

		variablename = 1

	end

	return FV.v2v({ [variablename] = value })

end
function FV.v2s(v, l, p, n, vtv, i, pt, path, tables, tI)



	if not tI then



		tI = { 0 }

	else

		tI[1] += 1

	end

	if typeof(v) == "number" then

		if v == math.huge then

			return "math.huge"

		elseif tostring(v):match("nan") then

			return "0/0 --[[NaN]]"

		end

		return tostring(v)

	elseif typeof(v) == "boolean" then

		return tostring(v)

	elseif typeof(v) == "string" then

		return FV.formatstr(v, l)

	elseif typeof(v) == "function" then

		return FV.f2s(v)

	elseif typeof(v) == "table" then

		return FV.t2s(v, l, p, n, vtv, i, pt, path, tables, tI)

	elseif typeof(v) == "Instance" then

		return FV.i2p(v)

	elseif typeof(v) == "userdata" then

		return "newproxy(true)"

	elseif type(v) == "userdata" then

		return FV.u2s(v)

	elseif type(v) == "vector" then

		return string.format("Vector3.new(%s, %s, %s)", FV.v2s(v.X), FV.v2s(v.Y), FV.v2s(v.Z))

	else

		return "nil --[[" .. typeof(v) .. "]]"

	end

end



--- value-to-variable

--- @param t any

function FV.v2v(t)

	topstr = ""

	bottomstr = ""

	getnilrequired = false

	local ret = ""

	local count = 1

	for i, v in pairs(t) do

		if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then

			ret = ret .. "local " .. i .. " = " .. FV.v2s(v, nil, nil, i, true) .. "\n"

		elseif tostring(i):match("^[%a_]+[%w_]*$") then

			ret = ret

				.. "local "

				.. tostring(i):lower()

				.. "_"

				.. tostring(count)

				.. " = "

				.. FV.v2s(v, nil, nil, tostring(i):lower() .. "_" .. tostring(count), true)

				.. "\n"

		else

			ret = ret

				.. "local "

				.. type(v)

				.. "_"

				.. tostring(count)

				.. " = "

				.. FV.v2s(v, nil, nil, type(v) .. "_" .. tostring(count), true)

				.. "\n"

		end

		count = count + 1

	end

	if getnilrequired then

		topstr = "function getNil(name,class) for _,v in pairs(getnilinstances())do if v.ClassName==class and v.Name==name then return v;end end end\n"

			.. topstr

	end

	if #topstr > 0 then

		ret = topstr .. "\n" .. ret

	end

	if #bottomstr > 0 then

		ret = ret .. bottomstr

	end

	return ret

end



--- table-to-string

--- @param t table

--- @param l number

--- @param p table

--- @param n string

--- @param vtv boolean

--- @param i any

--- @param pt table

--- @param path string

--- @param tables table

--- @param tI table

function FV.t2s(t, l, p, n, vtv, i, pt, path, tables, tI)

	local globalIndex = table.find(getgenv(), t) -- checks if table is a global

	if type(globalIndex) == "string" then

		return globalIndex

	end

	if not tI then

		tI = { 0 }

	end

	if not path then -- sets path to empty string (so it doesn't have to manually provided every time)

		path = ""

	end

	if not l then -- sets the level to 0 (for indentation) and tables for logging tables it already serialized

		l = 0

		tables = {}

	end

	if not p then -- p is the previous table but doesn't really matter if it's the first

		p = t

	end

	for _, v in pairs(tables) do -- checks if the current table has been serialized before

		if n and rawequal(v, t) then

			bottomstr = bottomstr

				.. "\n"

				.. tostring(n)

				.. tostring(path)

				.. " = "

				.. tostring(n)

				.. tostring(({ v2p(v, p) })[2])

			return "{} --[[DUPLICATE]]"

		end

	end

	table.insert(tables, t) -- logs table to past tables

	local s = "{" -- start of serialization

	local size = 0

	l = l + indent -- set indentation level

	for k, v in pairs(t) do -- iterates over table

		size = size + 1 -- changes size for max limit

		

		if rawequal(k, t) then -- checks if the table being iterated over is being used as an index within itself (yay, lua)

			bottomstr = bottomstr

				.. "\n"

				.. tostring(n)

				.. tostring(path)

				.. "["

				.. tostring(n)

				.. tostring(path)

				.. "]"

				.. " = "

				.. (

					rawequal(v, k) and tostring(n) .. tostring(path)

					or FV.v2s(v, l, p, n, vtv, k, t, path .. "[" .. tostring(n) .. tostring(path) .. "]", tables)

				)

			size -= 1

			continue

		end

		local currentPath = "" -- initializes the path of 'v' within 't'

		if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then -- cleanly handles table path generation (for the first half)

			currentPath = "." .. k

		else
                      if type(k) == "number" and k ~= k then
			currentPath = "[" .. FV.k2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]"
			end
		end

		if size % 100 == 0 then

			scheduleWait()

		end

		-- actually serializes the member of the table

		s = s

			.. "\n"

			.. string.rep(" ", l)

			.. "["

			.. FV.k2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI)

			.. "] = "

			.. FV.v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI)

			.. ","

	end

	if #s > 1 then -- removes the last comma because it looks nicer (no way to tell if it's done 'till it's done so...)

		s = s:sub(1, #s - 1)

	end

	if size > 0 then -- cleanly indents the last curly bracket

		s = s .. "\n" .. string.rep(" ", l - indent)

	end

	return s .. "}"

end



--- key-to-string

function FV.k2s(v, ...)

	

		if typeof(v) == "userdata" and getrawmetatable(v) then

			return string.format(

				'"<void> (%s)" --[[Potentially hidden data (tostring in SimpleSpy:HookRemote/GetRemoteFiredSignal at your own risk)]]',

				FV.safetostring(v)

			)

		elseif typeof(v) == "userdata" then

			return string.format('"<void> (%s)"', FV.safetostring(v))

		elseif type(v) == "userdata" and typeof(v) ~= "Instance" then

			return string.format('"<%s> (%s)"', typeof(v), tostring(v))

		elseif type(v) == "function" then

			return string.format('"<Function> (%s)"', tostring(v))

		end



	return FV.v2s(v, ...)

end



--- function-to-string

function FV.f2s(f)

	for k, x in pairs(getgenv()) do

		local isgucci, gpath

		if rawequal(x, f) then

			isgucci, gpath = true, ""

		elseif type(x) == "table" then

			isgucci, gpath = FV.v2p(f, x)

		end

		if isgucci and type(k) ~= "function" then

			if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then

				return k .. gpath

			else

				return "getgenv()[" .. FV.v2s(k) .. "]" .. gpath

			end

		end

	end

	if funcEnabled and debug.getinfo(f).name:match("^[%a_]+[%w_]*$") then

		return "function()end --[[" .. debug.getinfo(f).name .. "]]"

	end

	return "function()end --[[" .. tostring(f) .. "]]"

end



--- instance-to-path

--- @param i userdata

function FV.i2p(i)

	local player = getplayer(i)

	local parent = i

	local out = ""

	if parent == nil then

		return "nil"

	elseif player then

		while true do

			if parent and parent == player.Character then

				if player == Players.LocalPlayer then

					return 'game:GetService("Players").LocalPlayer.Character' .. out

				else

					return FV.i2p(player) .. ".Character" .. out

				end

			else

				if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then

					out = ":FindFirstChild(" .. FV.formatstr(parent.Name) .. ")" .. out

				else

					out = "." .. parent.Name .. out

				end

			end

			parent = parent.Parent

		end

	elseif parent ~= game then

		while true do

			if parent and parent.Parent == game then

				local service = game:FindService(parent.ClassName)

				if service then

					if parent.ClassName == "Workspace" then

						return "workspace" .. out

					else

						return 'game:GetService("' .. service.ClassName .. '")' .. out

					end

				else

					if parent.Name:match("[%a_]+[%w_]*") then

						return "game." .. parent.Name .. out

					else

						return "game:FindFirstChild(" .. FV.formatstr(parent.Name) .. ")" .. out

					end

				end

			elseif parent.Parent == nil then

				getnilrequired = true

				return "getNil(" .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out

			elseif parent == Players.LocalPlayer then

				out = ".LocalPlayer" .. out

			else

				if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then

					out = ":FindFirstChild(" .. formatstr(parent.Name) .. ")" .. out

				else

					out = "." .. parent.Name .. out

				end

			end

			parent = parent.Parent

		end

	else

		return "game"

	end

end



--- userdata-to-string: userdata

--- @param u userdata

function FV.u2s(u)

	if typeof(u) == "TweenInfo" then

		-- TweenInfo

		return "TweenInfo.new("

			.. tostring(u.Time)

			.. ", Enum.EasingStyle."

			.. tostring(u.EasingStyle)

			.. ", Enum.EasingDirection."

			.. tostring(u.EasingDirection)

			.. ", "

			.. tostring(u.RepeatCount)

			.. ", "

			.. tostring(u.Reverses)

			.. ", "

			.. tostring(u.DelayTime)

			.. ")"

	elseif typeof(u) == "Ray" then

		-- Ray

		return "Ray.new(" .. FV.u2s(u.Origin) .. ", " .. FV.u2s(u.Direction) .. ")"

	elseif typeof(u) == "NumberSequence" then

		-- NumberSequence

		local ret = "NumberSequence.new("

		for i, v in pairs(u.KeyPoints) do

			ret = ret .. tostring(v)

			if i < #u.Keypoints then

				ret = ret .. ", "

			end

		end

		return ret .. ")"

	elseif typeof(u) == "DockWidgetPluginGuiInfo" then

		-- DockWidgetPluginGuiInfo

		return "DockWidgetPluginGuiInfo.new(Enum.InitialDockState" .. tostring(u) .. ")"

	elseif typeof(u) == "ColorSequence" then

		-- ColorSequence

		local ret = "ColorSequence.new("

		for i, v in pairs(u.KeyPoints) do

			ret = ret .. "Color3.new(" .. tostring(v) .. ")"

			if i < #u.Keypoints then

				ret = ret .. ", "

			end

		end

		return ret .. ")"

	elseif typeof(u) == "BrickColor" then

		-- BrickColor

		return "BrickColor.new(" .. tostring(u.Number) .. ")"

	elseif typeof(u) == "NumberRange" then

		-- NumberRange

		return "NumberRange.new(" .. tostring(u.Min) .. ", " .. tostring(u.Max) .. ")"

	elseif typeof(u) == "Region3" then

		-- Region3

		local center = u.CFrame.Position

		local size = u.CFrame.Size

		local vector1 = center - size / 2

		local vector2 = center + size / 2

		return "Region3.new(" .. FV.u2s(vector1) .. ", " .. FV.u2s(vector2) .. ")"

	elseif typeof(u) == "Faces" then

		-- Faces

		local faces = {}

		if u.Top then

			table.insert(faces, "Enum.NormalId.Top")

		end

		if u.Bottom then

			table.insert(faces, "Enum.NormalId.Bottom")

		end

		if u.Left then

			table.insert(faces, "Enum.NormalId.Left")

		end

		if u.Right then

			table.insert(faces, "Enum.NormalId.Right")

		end

		if u.Back then

			table.insert(faces, "Enum.NormalId.Back")

		end

		if u.Front then

			table.insert(faces, "Enum.NormalId.Front")

		end

		return "Faces.new(" .. table.concat(faces, ", ") .. ")"

	elseif typeof(u) == "EnumItem" then

		return tostring(u)

	elseif typeof(u) == "Enums" then

		return "Enum"

	elseif typeof(u) == "Enum" then

		return "Enum." .. tostring(u)

	elseif typeof(u) == "RBXScriptSignal" then

		return "nil --[[RBXScriptSignal]]"

	elseif typeof(u) == "Vector3" then

		return string.format("Vector3.new(%s, %s, %s)", v2s(u.X), v2s(u.Y), v2s(u.Z))

	elseif typeof(u) == "CFrame" then

		local xAngle, yAngle, zAngle = u:ToEulerAnglesXYZ()

		return string.format(

			"CFrame.new(%s, %s, %s) * CFrame.Angles(%s, %s, %s)",

			FV.v2s(u.X),

			FV.v2s(u.Y),

			FV.v2s(u.Z),

			FV.v2s(xAngle),

			FV.v2s(yAngle),

			FV.v2s(zAngle)

		)

	elseif typeof(u) == "DockWidgetPluginGuiInfo" then

		return string.format(

			"DockWidgetPluginGuiInfo(%s, %s, %s, %s, %s, %s, %s)",

			"Enum.InitialDockState.Right",

			FV.v2s(u.InitialEnabled),

			FV.v2s(u.InitialEnabledShouldOverrideRestore),

			FV.v2s(u.FloatingXSize),

			FV.v2s(u.FloatingYSize),

			FV.v2s(u.MinWidth),

			FV.v2s(u.MinHeight)

		)

	elseif typeof(u) == "PathWaypoint" then

		return string.format("PathWaypoint.new(%s, %s)", v2s(u.Position), v2s(u.Action))

	elseif typeof(u) == "UDim" then

		return string.format("UDim.new(%s, %s)", v2s(u.Scale), v2s(u.Offset))

	elseif typeof(u) == "UDim2" then

		return string.format(

			"UDim2.new(%s, %s, %s, %s)",

			FV.v2s(u.X.Scale),

			FVv2s(u.X.Offset),

			FV.v2s(u.Y.Scale),

			FV.v2s(u.Y.Offset)

		)

	elseif typeof(u) == "Rect" then

		return string.format("Rect.new(%s, %s)", v2s(u.Min), v2s(u.Max))

	else

		return string.format("nil --[[%s]]", typeof(u))

	end

end



--- Gets the player an instance is descended from

function FV.getplayer(instance)

	for _, v in pairs(Players:GetPlayers()) do

		if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then

			return v

		end

	end

end



--- value-to-path (in table)

function FV.v2p(x, t, path, prev)

	if not path then

		path = ""

	end

	if not prev then

		prev = {}

	end

	if rawequal(x, t) then

		return true, ""

	end

	for i, v in pairs(t) do

		if rawequal(v, x) then

			if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then

				return true, (path .. "." .. i)

			else

				return true, (path .. "[" .. v2s(i) .. "]")

			end

		end

		if type(v) == "table" then

			local duplicate = false

			for _, y in pairs(prev) do

				if rawequal(y, v) then

					duplicate = true

				end

			end

			if not duplicate then

				table.insert(prev, t)

				local found

				found, p = v2p(x, v, path, prev)

				if found then

					if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then

						return true, "." .. i .. p

					else

						return true, "[" .. v2s(i) .. "]" .. p

					end

				end

			end

		end

	end

	return false, ""

end



--- format s: string, byte encrypt (for weird symbols)

function FV.formatstr(s, indentation)

	if not indentation then

		indentation = 0

	end

	local handled, reachedMax = FV.handlespecials(s, indentation)

	return '"'

		.. handled

		.. '"'

		.. (

			reachedMax

				and " --[[ MAXIMUM STRING SIZE REACHED, CHANGE '_G.SimpleSpyMaxStringSize' TO ADJUST MAXIMUM SIZE ]]"

			or ""

		)

end



--- Adds \'s to the text as a replacement to whitespace chars and other things because string.format can't yayeet

function FV.handlespecials(value, indentation)

	local buildStr = {}

	local i = 1

	local char = string.sub(value, i, i)

	local indentStr

	while char ~= "" do

		if char == '"' then

			buildStr[i] = '\\"'

		elseif char == "\\" then

			buildStr[i] = "\\\\"

		elseif char == "\n" then

			buildStr[i] = "\\n"

		elseif char == "\t" then

			buildStr[i] = "\\t"

		elseif string.byte(char) > 126 or string.byte(char) < 32 then

			buildStr[i] = string.format("\\%d", string.byte(char))

		else

			buildStr[i] = char

		end

		i = i + 1

		char = string.sub(value, i, i)

		if i % 200 == 0 then

			indentStr = indentStr or string.rep(" ", indentation + indent)

			table.move({ '"\n', indentStr, '... "' }, 1, 3, i, buildStr)

			i += 3

		end

	end

	return table.concat(buildStr)

end



-- safe (ish) tostring

function FV.safetostring(v: any)

	if typeof(v) == "userdata" or type(v) == "table" then

		local mt = getrawmetatable(v)

		local badtostring = mt and rawget(mt, "__tostring")

		if mt and badtostring then

			rawset(mt, "__tostring", nil)

			local out = tostring(v)

			rawset(mt, "__tostring", badtostring)

			return out

		end

	end

	return tostring(v)

end
--- schedules the provided function (and calls it with any args after)

function schedule(f, ...)

	table.insert(scheduled, { f, ... })

end



--- yields the current thread until the scheduler gives the ok

function scheduleWait()
pcall(function()
	local thread = coroutine.running()
	schedule(function()

		coroutine.resume(thread)

	end)

	coroutine.yield()
		end)
end



--- the big (well tbh small now) boi task scheduler himself, handles p much anything as quicc as possible

function taskscheduler()

	if not toggle then

		scheduled = {}

		return

	end

	if #scheduled > 1000 then

		table.remove(scheduled, #scheduled)

	end

	if #scheduled > 0 then

		local currentf = scheduled[1]

		table.remove(scheduled, 1)

		if type(currentf) == "table" and type(currentf[1]) == "function" then

			pcall(unpack(currentf))

		end

	end

end
return FV
