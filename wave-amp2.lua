--[[
wave-amp version 2.0.0

Copyright (c) 2021 b.jm021 (Benjamin J. Meyer)
Licensed under the GNU GPL 3 license
https://www.gnu.org/licenses/gpl-3.0.de.html
]]

--[[
wave-amp version 1.0.0

The MIT License (MIT)
Copyright (c) 2016 CrazedProgrammer
Licensed under the MIT license
https://opensource.org/license/mit/
]]

--[[
wave version 0.1.4

The MIT License (MIT)
Copyright (c) 2016 CrazedProgrammer
Licensed under the MIT license
https://opensource.org/license/mit/
]]

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


local wave = { }
wave.version = "2.0.0"

wave._oldSoundMap = {"harp", "bassattack", "bd", "snare", "hat"}
wave._newSoundMap_original = {"harp", "bass", "basedrum", "snare", "hat", "guitar", "flute", "bell", "chime", "xylophone", "iron_xylophone", "cow_bell", "didgeridoo", "bit", "banjo", "pling"}
wave._newSoundMap = deepcopy(wave._newSoundMap_original)
wave._defaultThrottle = 99
wave._defaultClipMode = 1
wave._maxInterval = 1
wave._isNewSystem = true
-- if _HOST then
--	wave._isNewSystem = _HOST:sub(15, #_HOST) >= "1.80"
-- end

wave.context = { }
wave.output = { }
wave.track = { }
wave.instance = { }

function wave.createContext(clock, volume)
	clock = clock or os.clock()
	volume = volume or 1.0

	local context = setmetatable({ }, {__index = wave.context})
	context.outputs = { }
	context.instances = { }
	context.vs = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	context.prevClock = clock
	context.volume = volume
	return context
end

function wave.context:addOutput(...)
	local output = wave.createOutput(...)
	self.outputs[#self.outputs + 1] = output
	return output
end

function wave.context:addOutputs(...)
	local outs = {...}
	if #outs == 1 then
		if not getmetatable(outs) then
			outs = outs[1]
		else
			if getmetatable(outs).__index ~= wave.outputs then
				outs = outs[1]
			end
		end
	end
	for i = 1, #outs do
		self:addOutput(outs[i])
	end
end

function wave.context:removeOutput(out)
	if type(out) == "number" then
		table.remove(self.outputs, out)
		return
	elseif type(out) == "table" then
		if getmetatable(out).__index == wave.output then
			for i = 1, #self.outputs do
				if out == self.outputs[i] then
					table.remove(self.outputs, i)
					return
				end
			end
			return
		end
	end
	for i = 1, #self.outputs do
		if out == self.outputs[i].native then
			table.remove(self.outputs, i)
			return
		end
	end
end

function wave.context:addInstance(...)
	local instance = wave.createInstance(...)
	self.instances[#self.instances + 1] = instance
	return instance
end

function wave.context:removeInstance(instance)
	if type(instance) == "number" then
		table.remove(self.instances, instance)
	else
		for i = 1, #self.instances do
			if self.instances == instance then
				table.remove(self.instances, i)
				return
			end
		end
	end
end

function wave.context:playNote(note, pitch, volume)
	volume = volume or 1.0

    if not (self.vs[note]) then
        self.vs[note] = 0
    end

	self.vs[note] = self.vs[note] + volume
	for i = 1, #self.outputs do
		self.outputs[i]:playNote(note, pitch, volume * self.volume)
	end
end

function wave.context:update(interval)
	local clock = os.clock()
	interval = interval or (clock - self.prevClock)

	self.prevClock = clock
	if interval > wave._maxInterval then
		interval = wave._maxInterval
	end
	for i = 1, #self.outputs do
		self.outputs[i].notes = 0
	end
	for i = 1, 10 do
		self.vs[i] = 0
	end
	if interval > 0 then
		for i = 1, #self.instances do
			local notes = self.instances[i]:update(interval)
			for j = 1, #notes / 3 do
				self:playNote(notes[j * 3 - 2], notes[j * 3 - 1], notes[j * 3])
			end
		end
	end
end



function wave.createOutput(out, volume, filter, throttle, clipMode)
	volume = volume or 1.0
	filter = filter or {true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true}
	throttle = throttle or wave._defaultThrottle
	clipMode = clipMode or wave._defaultClipMode

	local output = setmetatable({ }, {__index = wave.output})
	output.native = out
	output.volume = volume
	output.filter = filter
	output.notes = 0
	output.throttle = throttle
	output.clipMode = clipMode
	if type(out) == "function" then
		output.nativePlayNote = out
		output.type = "custom"
		return output
	elseif type(out) == "string" then
		if peripheral.getType(out) == "speaker" then
			if wave._isNewSystem then
				local nb = peripheral.wrap(out)
				output.type = "speaker"
				function output.nativePlayNote(note, pitch, volume)
					if output.volume * volume > 0 then
						if note <= 16 then
                            --nb.playSound("minecraft:block.note_block."..wave._newSoundMap[note], volume, math.pow(2, (pitch - 12) / 12))
                            nb.playNote(wave._newSoundMap[note], volume, pitch)
                        else
                            nb.playSound(wave._newSoundMap[note], volume, math.pow(2, (pitch - 12) / 12))
                        end
					end
				end
				return output
			end
		end
	elseif type(out) == "table" then
		if out.execAsync then
			output.type = "commands"
			if wave._isNewSystem then
				function output.nativePlayNote(note, pitch, volume)
                    if note <= 16 then
					    out.execAsync("playsound minecraft:block.note_block."..wave._newSoundMap[note].." record @a ~ ~ ~ "..tostring(volume).." "..tostring(math.pow(2, (pitch - 12) / 12)))
                    else
                        -- custom instruments
                        out.execAsync("playsound "..wave._newSoundMap[note].." record @a ~ ~ ~ "..tostring(volume).." "..tostring(math.pow(2, (pitch - 12) / 12)))
                    end
                end
			else
				function output.nativePlayNote(note, pitch, volume)
					out.execAsync("playsound note_block."..wave._oldSoundMap[note].." @a ~ ~ ~ "..tostring(volume).." "..tostring(math.pow(2, (pitch - 12) / 12)))
				end
			end
			return output
		elseif getmetatable(out) then
			if getmetatable(out).__index == wave.output then
				return out
			end
		end
	end
end

function wave.scanOutputs()
	local outs = { }
	if commands then
		outs[#outs + 1] = wave.createOutput(commands)
	end
	local sides = peripheral.getNames()
	for i = 1, #sides do
		if peripheral.getType(sides[i]) == "speaker" then
			outs[#outs + 1] = wave.createOutput(sides[i])
		end
	end
	return outs
end

function wave.output:playNote(note, pitch, volume)
	volume = volume or 1.0

	if self.clipMode == 1 then
		if pitch < 0 then
			pitch = 0
		elseif pitch > 24 then
			pitch = 24
		end
	elseif self.clipMode == 2 then
		if pitch < 0 then
			while pitch < 0 do
				pitch = pitch + 12
			end
		elseif pitch > 24 then
			while pitch > 24 do
				pitch = pitch - 12
			end
		end
	end
	--print("DEBUG Plaing note "..note.." with instrument "..wave._newSoundMap[note].. " !")
    if not (self.filter[note]) then
        self.filter[note] = true
    end
	if self.filter[note] and self.notes < self.throttle then
		--print("TEST")
		self.nativePlayNote(note, pitch, volume * self.volume)
		self.notes = self.notes + 1
	end
end


function wave.loadNewTrack(path)

	local track = setmetatable({ }, {__index = wave.track})
    track._soundMap = deepcopy(wave._newSoundMap_original) -- inherit default sound map
	local handle = fs.open(path, "rb")
	if not handle then return end

	local function readInt(size)
		local num = 0
		for i = 0, size - 1 do
			local byte = handle.read()
			if not byte then -- dont leave open file handles no matter what
				handle.close()
				return
			end
			num = num + byte * (256 ^ i)
		end
		return num
	end
	local function readStr()
		local length = readInt(4)
		if not length then return end
		local data = { }
		for i = 1, length do
			data[i] = string.char(handle.read())
		end
		return table.concat(data)
	end

	-- Part #1: Metadata
	print("New format bytes: " .. readInt(2))

	track.version = readInt(1);
	track.instCount = readInt(1);
	track.length = readInt(2) -- song length (ticks)
	track.height = readInt(2) -- song height
	track.name = readStr() -- song name
	track.author = readStr() -- song author
	track.originalAuthor = readStr() -- original song author
	track.description = readStr() -- song description
	track.tempo = readInt(2) / 100 -- tempo (ticks per second)
	track.autoSaving = readInt(1) == 0 and true or false -- auto-saving
	track.autoSavingDuration = readInt(1) -- auto-saving duration
	track.timeSignature = readInt(1) -- time signature (3 = 3/4)
	track.minutesSpent = readInt(4) -- minutes spent
	track.leftClicks = readInt(4) -- left clicks
	track.rightClicks = readInt(4) -- right clicks
	track.blocksAdded = readInt(4) -- blocks added
	track.blocksRemoved = readInt(4) -- blocks removed
	track.schematicFileName = readStr() -- midi/schematic file name
	track.loop = readInt(1)
	track.maxLoopCount = readInt(1)
	track.loopStartTick = readInt(2)





	-- Part #2: Notes
	track.layers = { }
	for i = 1, track.height do
		track.layers[i] = {name = "Layer "..i, volume = 1.0}
		track.layers[i].notes = { }
	end

	local tick = 0
	while true do
		local tickJumps = readInt(2)
		if tickJumps == 0 then break end
		tick = tick + tickJumps
		local layer = 0
		while true do
			local layerJumps = readInt(2)
			if layerJumps == 0 then
				track.length = tick
				break
			end
			layer = layer + layerJumps
			if layer > track.height then -- nbs can be buggy
				for i = track.height + 1, layer do
					track.layers[i] = {name = "Layer "..i, volume = 1.0}
					track.layers[i].notes = { }
				end
				track.height = layer
			end
			local instrument = readInt(1)
			local key = readInt(1)
			local noteBlockVolume = readInt(1)
			local noteBlockPan = readInt(1)
			local noteBlockPitch = readInt(2)
			if instrument <= 16 then -- nbs can be buggy
				track.layers[layer].notes[tick * 2 - 1] = instrument + 1
				track.layers[layer].notes[tick * 2] = key - 33
            else
                -- custom instruments
                track.layers[layer].notes[tick * 2 - 1] = instrument + 1
				track.layers[layer].notes[tick * 2] = key - 33
			end
		end
	end


	-- Part #3: Layers
	for i = 1, track.height do
		local name = readStr()
		local layerLock = readInt(1)
		local layerVolume = readInt(1)
		local layerStereo = readInt(1)
		if not name then print("NO NAME") break end -- if layer data doesnt exist, abort
		track.layers[i].name = name
		track.layers[i].volume = layerVolume / 100
	end


    -- Part #4: Custom instruments
    local customInstCount = readInt(1)
    for i = 1, customInstCount do
        local name = readStr() -- sound name without
        local instFilename = readStr()
        local key = readInt(1)
        local press = readInt(1)
        -- Create new instrument
        table.insert(track._soundMap, name)
    end


	handle.close()
	return track
end

function wave.loadTrack(path)
	local track = setmetatable({ }, {__index = wave.track})
	local handle = fs.open(path, "rb")
	if not handle then return end

	local function readInt(size)
		local num = 0
		for i = 0, size - 1 do
			local byte = handle.read()
			if not byte then -- dont leave open file handles no matter what
				handle.close()
				return
			end
			num = num + byte * (256 ^ i)
		end
		return num
	end
	local function readStr()
		local length = readInt(4)
		if not length then return end
		local data = { }
		for i = 1, length do
			data[i] = string.char(handle.read())
		end
		return table.concat(data)
	end

	-- Part #1: Metadata

	firstBytes = readInt(2)
	if firstBytes == 0 then
		print("Found new NBS file; Using new loader...")
		handle.close()
		return wave.loadNewTrack(path)
	end

	track.length = firstBytes -- song length (ticks)
	track.height = readInt(2) -- song height
	track.name = readStr() -- song name
	track.author = readStr() -- song author
	track.originalAuthor = readStr() -- original song author
	track.description = readStr() -- song description
	track.tempo = readInt(2) / 100 -- tempo (ticks per second)
	track.autoSaving = readInt(1) == 0 and true or false -- auto-saving
	track.autoSavingDuration = readInt(1) -- auto-saving duration
	track.timeSignature = readInt(1) -- time signature (3 = 3/4)
	track.minutesSpent = readInt(4) -- minutes spent
	track.leftClicks = readInt(4) -- left clicks
	track.rightClicks = readInt(4) -- right clicks
	track.blocksAdded = readInt(4) -- blocks added
	track.blocksRemoved = readInt(4) -- blocks removed
	track.schematicFileName = readStr() -- midi/schematic file name

	-- Part #2: Notes
	track.layers = { }
	for i = 1, track.height do
		track.layers[i] = {name = "Layer "..i, volume = 1.0}
		track.layers[i].notes = { }
	end

	local tick = 0
	while true do
		local tickJumps = readInt(2)
		if tickJumps == 0 then break end
		tick = tick + tickJumps
		local layer = 0
		while true do
			local layerJumps = readInt(2)
			if layerJumps == 0 then
				track.length = tick
				break
			end
			layer = layer + layerJumps
			if layer > track.height then -- nbs can be buggy
				for i = track.height + 1, layer do
					track.layers[i] = {name = "Layer "..i, volume = 1.0}
					track.layers[i].notes = { }
				end
				track.height = layer
			end
			local instrument = readInt(1)
			local key = readInt(1)
			if instrument <= 9 then -- nbs can be buggy
				track.layers[layer].notes[tick * 2 - 1] = instrument + 1
				track.layers[layer].notes[tick * 2] = key - 33
			end
		end
	end

	-- Part #3: Layers
	for i = 1, track.height do
		local name = readStr()
		if not name then break end -- if layer data doesnt exist, abort
		track.layers[i].name = name
		track.layers[i].volume = readInt(1) / 100
	end

	handle.close()
	return track
end



function wave.createInstance(track, volume, playing, loop)
	volume = volume or 1.0
	playing = (playing == nil) or playing
	loop = (loop ~=  nil) and loop

	if getmetatable(track).__index == wave.instance then
		return track
	end
	local instance = setmetatable({ }, {__index = wave.instance})
	instance.track = track
	instance.volume = volume or 1.0
	instance.playing = playing
	instance.loop = loop
	instance.tick = 1
	return instance
end

function wave.instance:update(interval)
	local notes = { }
	if self.playing then
		local dticks = interval * self.track.tempo
		local starttick = self.tick
		local endtick = starttick + dticks
		local istarttick = math.ceil(starttick)
		local iendtick = math.ceil(endtick) - 1
		for i = istarttick, iendtick do
			for j = 1, self.track.height do
				if self.track.layers[j].notes[i * 2 - 1] then
					notes[#notes + 1] = self.track.layers[j].notes[i * 2 - 1]
					notes[#notes + 1] = self.track.layers[j].notes[i * 2]
					notes[#notes + 1] = self.track.layers[j].volume
				end
			end
		end
		self.tick = self.tick + dticks

		if endtick > self.track.length then
			self.tick = 1
			self.playing = self.loop
		end
	end
	return notes
end



local cmdHelp = [[
-l                   lists all outputs connected to the computer.
-c <config file>     loads the parameters from a file.
parameters are separated by newlines.
-t <theme file>      loads the theme from a file.
-f <filter[:second]> sets the note filter for the outputs.
examples:
 -f 10111            sets the filter for all outputs to remove the bass instrument.
 -f 10011:01100      sets the filter so the bass and basedrum instruments only come out of the second output
-v <volume[:second]> sets the volume for the outputs.
--nrm --stp --rep --shf   sets the play mode.
--noui --noinput     disables the ui/keyboard input
--exit			     to reboot the system after a song played]]


local trackMode = 1
-- 1 = normal (go to next song on finish)
-- 2 = stop (stop on finish)
-- 3 = repeat (restart song on finish)
-- 4 = shuffle (go to random song on finish)

local files = { }
local tracks = { }
local context, track, instance

-- ui stuff
local noUI = false
local exitAfter = false
local noInput = false
local screenWidth, screenHeight = term.getSize()
local trackScroll = 0
local currentTrack = 1
local vsEasings = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local vsStep = 10
local vsDecline = 0.25

-- theme
local theme = term.isColor() and
		{
			topBar = colors.lime,
			topBarTitle = colors.white,
			topBarOption = colors.white,
			topBarOptionSelected = colors.lightGray,
			topBarClose = colors.white,
			song = colors.black,
			songBackground = colors.white,
			songSelected = colors.black,
			songSelectedBackground = colors.lightGray,
			scrollBackground = colors.lightGray,
			scrollBar = colors.gray,
			scrollButton = colors.black,
			visualiserBar = colors.lime,
			visualiserBackground = colors.green,
			progressTime = colors.white,
			progressBackground = colors.lightGray,
			progressLine = colors.gray,
			progressNub = colors.gray,
			progressNubBackground = colors.gray,
			progressNubChar = "=",
			progressButton = colors.white
		}
		or
		{
			topBar = colors.lightGray,
			topBarTitle = colors.white,
			topBarOption = colors.white,
			topBarOptionSelected = colors.gray,
			topBarClose = colors.white,
			song = colors.black,
			songBackground = colors.white,
			songSelected = colors.black,
			songSelectedBackground = colors.lightGray,
			scrollBackground = colors.lightGray,
			scrollBar = colors.gray,
			scrollButton = colors.black,
			visualiserBar = colors.black,
			visualiserBackground = colors.gray,
			progressTime = colors.white,
			progressBackground = colors.lightGray,
			progressLine = colors.gray,
			progressNub = colors.gray,
			progressNubBackground = colors.gray,
			progressNubChar = "=",
			progressButton = colors.white
		}

local running = true



local function addFiles(path)
	local dirstack = {path}
	while #dirstack > 0 do
		local dir = dirstack[1]
		table.remove(dirstack, 1)
		if dir ~= "rom" then
			for _, v in pairs(fs.list(dir)) do
				local path = (dir == "") and v or dir.."/"..v
				if fs.isDir(path) then
					dirstack[#dirstack + 1] = path
				elseif path:sub(#path - 3, #path) == ".nbs" then
					files[#files + 1] = path
				end
			end
		end
	end
end

local function init(args)
	local volumes = { }
	local filters = { }
	local outputs = wave.scanOutputs()
	local timestamp = 0

	if #outputs == 0 then
		error("no outputs found")
	end

	local i, argtype = 1
	while i <= #args do
		if not argtype then

			if args[i] == "--exit" then
				exitAfter = true;
			end

			if args[i] == "-h" then
				print(cmdHelp)
				noUI = true
				running = false
				return
			elseif args[i] == "-c" or args[i] == "-v" or args[i] == "-f" or args[i] == "-t" then
				argtype = args[i]
			elseif args[i] == "-l" then
				print(#outputs.." outputs detected:")
				for i = 1, #outputs do
					print(i..":", outputs[i].type, type(outputs[i].native) == "string" and outputs[i].native or "")
				end
				noUI = true
				running = false
				return
			elseif args[i] == "--noui" then
				noUI = true
			elseif args[i] == "--noinput" then
				noInput = true
			elseif args[i] == "--nrm" then
				trackMode = 1
			elseif args[i] == "--stp" then
				trackMode = 2
			elseif args[i] == "--rep" then
				trackMode = 3
			elseif args[i] == "--shf" then
				trackMode = 4
			else
				local path = shell.resolve(args[i])
				if fs.isDir(path) then
					addFiles(path)
				elseif fs.exists(path) then
					files[#files + 1] = path
				end
			end
		else
			if argtype == "-c" then
				local path = shell.resolve(args[i])
				local handle = fs.open(path, "r")
				if not handle then
					error("config file does not exist: "..path)
				end
				local line = handle.readLine()
				while line do
					args[#args + 1] = line
					line = handle.readLine()
				end
				handle.close()
			elseif argtype == "-t" then
				local path = shell.resolve(args[i])
				local handle = fs.open(path, "r")
				if not handle then
					error("theme file does not exist: "..path)
				end
				local data = handle.readAll()
				handle.close()
				for k, v in pairs(colors) do
					data = data:gsub("colors."..k, tostring(v))
				end
				for k, v in pairs(colours) do
					data = data:gsub("colours."..k, tostring(v))
				end
				local newtheme = textutils.unserialize(data)
				for k, v in pairs(newtheme) do
					theme[k] = v
				end
			elseif argtype == "-v" then
				for str in args[i]:gmatch("([^:]+)") do
					local vol = tonumber(str)
					if vol then
						if vol >= 0 and vol <= 1 then
							volumes[#volumes + 1] = vol
						else
							error("invalid volume value: "..str)
						end
					else
						error("invalid volume value: "..str)
					end
				end
			elseif argtype == "-f" then
				for str in args[i]:gmatch("([^:]+)") do
					if #str == 10 then
						local filter = { }
						for i = 1, 16 do
							if str:sub(i, i) == "1" then
								filter[i] = true
							elseif str:sub(i, i) == "0" then
								filter[i] = false
							else
								error("invalid filter value: "..str)
							end
						end
						filters[#filters + 1] = filter
					else
						error("invalid filter value: "..str)
					end
				end
			end
			argtype = nil
		end
		i = i + 1
	end

	if #files == 0 then
		addFiles("")
	end

	i = 1
	print("loading tracks...")
	while i <= #files do
		local track
		pcall(function () track = wave.loadTrack(files[i]) end)
		if not track then
			print("failed to load "..files[i])
			os.sleep(0.2)
			table.remove(files, i)
		else
			tracks[i] = track
			print("loaded "..files[i])
			i = i + 1
		end
		if i % 10 == 0 then
			os.sleep(0)
		end
	end
	if #files == 0 then
		error("no tracks found")
	end

	if #volumes == 0 then
		volumes[1] = 1
	end
	if #filters == 0 then
		filters[1] = {true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true}
	end
	if #volumes == 1 then
		for i = 2, #outputs do
			volumes[i] = volumes[1]
		end
	end
	if #filters == 1 then
		for i = 2, #outputs do
			filters[i] = filters[1]
		end
	end
	if #volumes ~= #outputs then
		error("invalid amount of volume values: "..#volumes.." (must be 1 or "..#outputs..")")
	end
	if #filters ~= #outputs then
		error("invalid amount of filter values: "..#filters.." (must be 1 or "..#outputs..")")
	end

	for i = 1, #outputs do
		outputs[i].volume = volumes[i]
		outputs[i].filter = filters[i]
	end

	context = wave.createContext()
	context:addOutputs(outputs)
end

local function formatTime(secs)
	local mins = math.floor(secs / 60)
	secs = secs - mins * 60
	return string.format("%01d:%02d", mins, secs)
end

local function drawStatic()
	if noUI then return end
	term.setCursorPos(1, 1)
	term.setBackgroundColor(theme.topBar)
	term.setTextColor(theme.topBarTitle)
	term.write("wave-amp2 (with OpenNBS support)")
	term.write((" "):rep(screenWidth - 49))
	term.setTextColor(trackMode == 1 and theme.topBarOptionSelected or theme.topBarOption)
	term.write("nrm ")
	term.setTextColor(trackMode == 2 and theme.topBarOptionSelected or theme.topBarOption)
	term.write("stp ")
	term.setTextColor(trackMode == 3 and theme.topBarOptionSelected or theme.topBarOption)
	term.write("rep ")
	term.setTextColor(trackMode == 4 and theme.topBarOptionSelected or theme.topBarOption)
	term.write("shf ")
	term.setTextColor(theme.topBarClose)
	term.write("X")

	local scrollnub = math.floor(trackScroll / (#tracks - screenHeight + 7) * (screenHeight - 10) + 0.5)

	term.setTextColor(theme.song)
	term.setBackgroundColor(theme.songBackground)
	for i = 1, screenHeight - 7 do
		local index = i + trackScroll
		term.setCursorPos(1, i + 1)
		term.setTextColor(index == currentTrack and theme.songSelected or theme.song)
		term.setBackgroundColor(index == currentTrack and theme.songSelectedBackground or theme.songBackground)
		local str = ""
		if tracks[index] then
			local track = tracks[index]
			str = formatTime(track.length / track.tempo).." "
			if #track.name > 0 then
				str = str..(#track.originalAuthor == 0 and track.author or track.originalAuthor).." - "..track.name
			else
				local name = fs.getName(files[index])
				str = str..name:sub(1, #name - 4)
			end
		end
		if #str > screenWidth - 1 then
			str = str:sub(1, screenWidth - 3)..".."
		end
		term.write(str)
		term.write((" "):rep(screenWidth - 1 - #str))
		term.setBackgroundColor((i >= scrollnub + 1 and i <= scrollnub + 3) and theme.scrollBar or theme.scrollBackground)
		if i == 1 then
			term.setTextColor(theme.scrollButton)
			term.write(_HOST and "\30" or "^")
		elseif i == screenHeight - 7 then
			term.setTextColor(theme.scrollButton)
			term.write(_HOST and "\31" or "v")
		else
			term.write(" ")
		end
	end
end

local function drawDynamic()
	if noUI then return end
	for i = 1, 10 do
		vsEasings[i] = vsEasings[i] - vsDecline
		if vsEasings[i] < 0 then
			vsEasings[i] = 0
		end
		local part = context.vs[i] > vsStep and vsStep or context.vs[i]
		if vsEasings[i] < part then
			vsEasings[i] = part
		end
		local full = math.floor(part / vsStep * screenWidth + 0.5)
		local easing = math.floor(vsEasings[i] / vsStep * screenWidth + 0.5)
		term.setCursorPos(1, screenHeight - 6 + i)
		term.setBackgroundColor(theme.visualiserBar)
		term.setTextColor(theme.visualiserBackground)
		term.write((" "):rep(full))
		term.write((_HOST and "\127" or "#"):rep(math.floor((easing - full) / 2)))
		term.setBackgroundColor(theme.visualiserBackground)
		term.setTextColor(theme.visualiserBar)
		term.write((_HOST and "\127" or "#"):rep(math.ceil((easing - full) / 2)))
		term.write((" "):rep(screenWidth - easing))
	end

	local progressnub = math.floor((instance.tick / track.length) * (screenWidth - 14) + 0.5)

	term.setCursorPos(1, screenHeight)
	term.setTextColor(theme.progressTime)
	term.setBackgroundColor(theme.progressBackground)
	term.write(formatTime(instance.tick / track.tempo))

	term.setTextColor(theme.progressLine)
	term.write("\136")
	term.write(("\140"):rep(progressnub))
	term.setTextColor(theme.progressNub)
	term.setBackgroundColor(theme.progressNubBackground)
	term.write(theme.progressNubChar)
	term.setTextColor(theme.progressLine)
	term.setBackgroundColor(theme.progressBackground)
	term.write(("\140"):rep(screenWidth - 14 - progressnub))
	term.write("\132")

	term.setTextColor(theme.progressTime)
	term.write(formatTime(track.length / track.tempo).." ")
	term.setTextColor(theme.progressButton)
	term.write(instance.playing and (_HOST and "|\016" or "|>") or "||")
end

local function playSong(index)
	if index >= 1 and index <= #tracks then
		currentTrack = index
		track = tracks[currentTrack]
        wave._newSoundMap = track._soundMap or wave._newSoundMap_original -- change the sound map
		context:removeInstance(1)
		instance = context:addInstance(track, 1, trackMode ~= 2, trackMode == 3)
		if currentTrack <= trackScroll then
			trackScroll = currentTrack - 1
		end
		if currentTrack > trackScroll + screenHeight - 7 then
			trackScroll = currentTrack - screenHeight + 7
		end
		drawStatic()
	end
end

local function nextSong()
	if trackMode == 1 then
		playSong(currentTrack + 1)
	elseif trackMode == 4 then
		playSong(math.random(#tracks))
	end
end

local function setScroll(scroll)
	trackScroll = scroll
	if trackScroll > #tracks - screenHeight + 7 then
		trackScroll = #tracks - screenHeight + 7
	end
	if trackScroll < 0 then
		trackScroll = 0
	end
	drawStatic()
end

local function handleClick(x, y)
	if noUI then return end
	if y == 1 then
		if x == screenWidth then
			running = false
		elseif x >= screenWidth - 16 and x <= screenWidth - 2 and (x - screenWidth + 1) % 4 ~= 0 then
			trackMode = math.floor((x - screenWidth + 16) / 4) + 1
			instance.loop = trackMode == 3
			drawStatic()
		end
	elseif x < screenWidth and y >= 2 and y <= screenHeight - 6 then
		playSong(y - 1 + trackScroll)
	elseif x == screenWidth and y == 2 then
		setScroll(trackScroll - 2)
	elseif x == screenWidth and y == screenHeight - 6 then
		setScroll(trackScroll + 2)
	elseif x == screenWidth and y >= 3 and y <= screenHeight - 7 then
		setScroll(math.floor((y - 3) / (screenHeight - 10) * (#tracks - screenHeight + 7 ) + 0.5))
	elseif y == screenHeight then
		if x >= screenWidth - 1 and x <= screenWidth then
			instance.playing = not instance.playing
		elseif x >= 6 and x <= screenWidth - 8 then
			instance.tick = ((x - 6) / (screenWidth - 14)) * track.length
		end
	end
end

local function handleScroll(x, y, scroll)
	if noUI then return end
	if y >= 2 and y <= screenHeight - 6 then
		setScroll(trackScroll + scroll * 2)
	end
end

local function handleKey(key)
	if noInput then return end
	if key == keys.space then
		instance.playing = not instance.playing
	elseif key == keys.n then
		nextSong()
	elseif key == keys.p then
		playSong(currentTrack - 1)
	elseif key == keys.m then
		context.volume = (context.volume == 0) and 1 or 0
	elseif key == keys.left then
		instance.tick = instance.tick - track.tempo * 10
		if instance.tick < 1 then
			instance.tick = 1
		end
	elseif key == keys.right then
		instance.tick = instance.tick + track.tempo * 10
	elseif key == keys.up then
		context.volume = (context.volume == 1) and 1 or context.volume + 0.1
	elseif key == keys.down then
		context.volume = (context.volume == 0) and 0 or context.volume - 0.1
	elseif key == keys.j then
		setScroll(trackScroll + 2)
	elseif key == keys.k then
		setScroll(trackScroll - 2)
	elseif key == keys.pageUp then
		setScroll(trackScroll - 5)
	elseif key == keys.pageDown then
		setScroll(trackScroll + 5)
	elseif key == keys.leftShift then
		trackMode = trackMode % 4 + 1
		drawStatic()
	elseif key == keys.backspace then
		running = false
	end
end

local function run()
	playSong(1)
	drawStatic()
	drawDynamic()
	local timer = os.startTimer(0.05)
	while running do
		local e = {os.pullEventRaw()}
		if e[1] == "timer" and e[2] == timer then
			timer = os.startTimer(0)
			local prevtick = instance.tick
			context:update()
			if prevtick > 1 and instance.tick == 1 then
				if exitAfter then
					os.reboot()
				end
				nextSong()
			end
			drawDynamic()
		elseif e[1] == "terminate" then
			running = false
		elseif e[1] == "term_resize" then
			screenWidth, screenHeight = term.getSize()
		elseif e[1] == "mouse_click" then
			handleClick(e[3], e[4])
		elseif e[1] == "mouse_scroll" then
			handleScroll(e[3], e[4], e[2])
		elseif e[1] == "key" then
			handleKey(e[2])
		end
	end
end

local function exit()
	if noUI then return end
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1, 1)
	term.clear()
end

init({...})
run()
exit()
