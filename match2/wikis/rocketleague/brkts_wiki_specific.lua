local p = require("Module:Brkts/WikiSpecific/Base")

local Logic = require('Module:Logic')
local String = require('Module:StringUtils')
local Variables = require('Module:Variables')
local Table = require('Module:Table')
local TypeUtil = require('Module:TypeUtil')
local Template = require('Module:Template')
local json = require("Module:Json")
local getIconName = require("Module:IconName").luaGet
local _frame

local ALLOWED_STATUSES = { "W", "FF", "DQ", "L" }
local MAX_NUM_OPPONENTS = 2
local MAX_NUM_PLAYERS = 10
local MAX_NUM_VODGAMES = 20

-- containers for process helper functions
local matchFunctions = {}
local mapFunctions = {}
local opponentFunctions = {}

-- called from Module:MatchGroup
function p.processMatch(frame, match)
	_frame = frame
	if type(match) == "string" then
		match = json.parse(match)
	end

	-- process match
	match = matchFunctions.getDateStuff(match)
	match = matchFunctions.getOpponents(match)
	match = matchFunctions.getTournamentVars(match)
	match = matchFunctions.getVodStuff(match)
	match = matchFunctions.getExtraData(match)

	return match
end

-- called from Module:Match/Subobjects
function p.processMap(frame, map)
	_frame = frame
	if type(map) == "string" then
		map = json.parse(map)
	end

	-- process map
	map = mapFunctions.getExtraData(map)
	map = mapFunctions.getScoresAndWinner(map)
	map = mapFunctions.getTournamentVars(map)
	map = mapFunctions.getParticipantsData(map)

	return map
end

-- called from Module:Match/Subobjects
function p.processOpponent(frame, opponent)
	_frame = frame
	if type(opponent) == "string" then
		opponent = json.parse(opponent)
	end

	-- process opponent
	if not Logic.isEmpty(opponent.template) then
		opponent.name = opponent.name or opponentFunctions.getTeamName(opponent.template)
		opponent.icon = opponent.icon or opponentFunctions.getIconName(opponent.template)
	end

	return opponent
end

-- called from Module:Match/Subobjects
function p.processPlayer(frame, player)
	_frame = frame
	if type(player) == "string" then
		player = json.parse(player)
	end
	return player
end

--
--
-- function to sort out winner/placements
function p._placementSortFunction(table, key1, key2)
	local op1 = table[key1]
	local op2 = table[key2]
	local op1norm = op1.status == "S"
	local op2norm = op2.status == "S"
	if op1norm then
		if op2norm then
			return tonumber(op1.score) > tonumber(op2.score)
		else return true end
	else
		if op2norm then return false
		elseif op1.status == "W" then return true
		elseif op1.status == "DQ" then return false
		elseif op2.status == "W" then return false
		elseif op2.status == "DQ" then return true
		else return true end
	end
end

--
-- match related functions
--
function matchFunctions.getDateStuff(match)
	local lang = mw.getContentLanguage()
	-- parse date string with abbr
	if not Logic.isEmpty(match.date) then
		local matchString = match.date or ""
		local timezone = String.split(
			String.split(matchString, "data%-tz%=\"")[2] or "",
			"\"")[1] or String.split(
			String.split(matchString, "data%-tz%=\'")[2] or "",
			"\'")[1] or ""
		local matchDate = String.explode(matchString, "<", 0):gsub("-", "")
		match.date = matchDate .. timezone
		match.dateexact = String.contains(match.date, "%+") or String.contains(match.date, "%-")
	else
		match.date = lang:formatDate(
			'c',
			(Variables.varDefault("tournament_date", "") or "")
				.. " + " .. Variables.varDefault("num_missing_dates", "0") .. " second"
		)
		match.dateexact = false
		Variables.varDefine("num_missing_dates", Variables.varDefault("num_missing_dates", 0) + 1)
	end
	return match
end

function matchFunctions.getTournamentVars(match)
	match.mode = Logic.emptyOr(match.mode, Variables.varDefault("tournament_mode", "3v3"))
	match.type = Logic.emptyOr(match.type, Variables.varDefault("tournament_type"))
	match.tournament = Logic.emptyOr(match.tournament, Variables.varDefault("tournament_name"))
	match.tickername = Logic.emptyOr(match.tickername, Variables.varDefault("tournament_ticker_name"))
	match.shortname = Logic.emptyOr(match.shortname, Variables.varDefault("tournament_shortname"))
	match.series = Logic.emptyOr(match.series, Variables.varDefault("tournament_series"))
	match.icon = Logic.emptyOr(match.icon, Variables.varDefault("tournament_icon"))
	match.liquipediatier = Logic.emptyOr(match.liquipediatier, Variables.varDefault("tournament_tier"))
	return match
end

function matchFunctions.getVodStuff(match)
	match.stream = match.stream or {}
	match.stream = json.stringify({
		stream = Logic.emptyOr(match.stream.stream, Variables.varDefault("stream")),
		twitch = Logic.emptyOr(match.stream.twitch or match.twitch, Variables.varDefault("twitch")),
		twitch2 = Logic.emptyOr(match.stream.twitch2 or match.twitch2, Variables.varDefault("twitch2")),
		afreeca = Logic.emptyOr(match.stream.afreeca or match.afreeca, Variables.varDefault("afreeca")),
		afreecatv = Logic.emptyOr(match.stream.afreecatv or match.afreecatv, Variables.varDefault("afreecatv")),
		dailymotion = Logic.emptyOr(match.stream.dailymotion or match.dailymotion, Variables.varDefault("dailymotion")),
		douyu = Logic.emptyOr(match.stream.douyu or match.douyu, Variables.varDefault("douyu")),
		smashcast = Logic.emptyOr(match.stream.smashcast or match.smashcast, Variables.varDefault("smashcast")),
		youtube = Logic.emptyOr(match.stream.youtube or match.youtube, Variables.varDefault("youtube"))
	})
	match.vod = Logic.emptyOr(match.vod, Variables.varDefault("vod"))

	-- apply vodgames
	for index = 1, MAX_NUM_VODGAMES do
		local vodgame = match["vodgame" .. index]
		if not Logic.isEmpty(vodgame) then
			local map = Logic.emptyOr(match["map" .. index], nil, {})
			if type(map) == "string" then
				map = json.parse(map)
			end
			map.vod = map.vod or vodgame
			match["map" .. index] = map
		end
	end
	return match
	end

	function matchFunctions.getExtraData(match)
	local opponent1 = match.opponent1 or {}
	local opponent2 = match.opponent2 or {}
	match.extradata = json.stringify({
		matchsection = Variables.varDefault("matchsection"),
		team1icon = getIconName(opponent1.template or ""),
		team2icon = getIconName(opponent2.template or ""),
		lastgame = Variables.varDefault("last_game"),
		comment = match.comment,
		octane = match.octane,
		liquipediatier2 = Variables.varDefault("tournament_tier2"),
		isconverted = 0
	})
	return match
	end

	function matchFunctions.getOpponents(args)
	-- read opponents and ignore empty ones
	local opponents = {}
	local isScoreSet = false
	for opponentIndex = 1, MAX_NUM_OPPONENTS do
		-- read opponent
		local opponent = args["opponent" .. opponentIndex]
		if not Logic.isEmpty(opponent) then
			if type(opponent) == "string" then
				opponent = json.parse(opponent)
			end
			-- apply status
			if TypeUtil.isNumeric(opponent.score) then
				opponent.status = "S"
				isScoreSet = true
			elseif Table.includes(ALLOWED_STATUSES, opponent.score) then
				opponent.status = opponent.score
				opponent.score = -1
			end
			opponents[opponentIndex] = opponent

			-- get players from vars for teams
			if opponent.type == "team" and not Logic.isEmpty(opponent.name) then
				args = matchFunctions.getPlayers(args, opponentIndex, opponent.name)
			end
		end
	end

	-- see if match should actually be finished if score is set
	if isScoreSet and not Logic.readBool(args.finished) then
		local currentUnixTime = os.time(os.date("!*t"))
		local lang = mw.getContentLanguage()
		local matchUnixTime = tonumber(lang:formatDate('U', args.date))
		local threshold = args.dateexact and 30800 or 86400
		if matchUnixTime + threshold < currentUnixTime then
			args.finished = true
		end
	end

	-- apply placements and winner if finshed
	if Logic.readBool(args.finished) then
		local placement = 1
		-- luacheck: push ignore
		for opponentIndex, opponent in Table.iter.spairs(opponents, p._placementSortFunction) do
			if placement == 1 then
				args.winner = opponentIndex
			end
			opponent.placement = placement
			args["opponent" .. opponentIndex] = opponent
			placement = placement + 1
		end
	-- luacheck: pop
	-- only apply arg changes otherwise
	else
		for opponentIndex, opponent in pairs(opponents) do
			args["opponent" .. opponentIndex] = opponent
		end
	end
	return args
	end

	function matchFunctions.getPlayers(match, opponentIndex, teamName)
	for playerIndex = 1, MAX_NUM_PLAYERS do
		-- parse player
		local player = match["opponent" .. opponentIndex .. "_p" .. playerIndex] or {}
		if type(player) == "string" then
			player = json.parse(player)
		end
		player.name = player.name or Variables.varDefault(teamName .. "_p" .. playerIndex)
		player.flag = player.flag or Variables.varDefault(teamName .. "_p" .. playerIndex .. "flag")
		if not Table.isEmpty(player) then
			match["opponent" .. opponentIndex .. "_p" .. playerIndex] = player
		end
	end
	return match
	end

	--
	-- map related functions
	--
	function mapFunctions.getExtraData(map)
	map.extradata = json.stringify({
		ot = map.ot,
		otlength = map.otlength,
		comment = map.comment
	})
	return map
	end

	function mapFunctions.getScoresAndWinner(map)
	map.scores = {}
	local indexedScores = {}
	for scoreIndex = 1, MAX_NUM_OPPONENTS do
		-- read scores
		local score = map["score" .. scoreIndex]
		local obj = {}
		if not Logic.isEmpty(score) then
			if TypeUtil.isNumeric(score) then
				obj.status = "S"
				obj.score = score
			elseif Table.includes(ALLOWED_STATUSES, score) then
				obj.status = score
				obj.score = -1
			end
			table.insert(map.scores, score)
			indexedScores[scoreIndex] = obj
		else
			break
		end
	end
	-- luacheck: push ignore
	for scoreIndex, _ in Table.iter.spairs(indexedScores, p._placementSortFunction) do
		map.winner = scoreIndex
		break
	end
	-- luacheck: pop

	return map
	end

	function mapFunctions.getTournamentVars(map)
	map.mode = Logic.emptyOr(map.mode, Variables.varDefault("tournament_mode", "3v3"))
	map.type = Logic.emptyOr(map.type, Variables.varDefault("tournament_type"))
	map.tournament = Logic.emptyOr(map.tournament, Variables.varDefault("tournament_name"))
	map.tickername = Logic.emptyOr(map.tickername, Variables.varDefault("tournament_ticker_name"))
	map.shortname = Logic.emptyOr(map.shortname, Variables.varDefault("tournament_shortname"))
	map.series = Logic.emptyOr(map.series, Variables.varDefault("tournament_series"))
	map.icon = Logic.emptyOr(map.icon, Variables.varDefault("tournament_icon"))
	map.liquipediatier = Logic.emptyOr(map.liquipediatier, Variables.varDefault("tournament_tier"))
	return map
	end

	function mapFunctions.getParticipantsData(map)
	local participants = map.participants or {}
	if type(participants) == "string" then
		participants = json.parse(participants)
	end

	-- fill in goals from goal progression
	local scorers = {}
	for g = 1, 1000 do
		local scorer = map["goal" .. g .. "player"]
		if Logic.isEmpty(scorer) then
			break
		elseif scorer:match("op%d_p%d") then
			scorer = scorer:gsub("op", ""):gsub("p", "")
			scorers[scorer] = (scorers[scorer] or 0) + 1
		end
	end
	for scorer, goals in pairs(scorers) do
		participants[scorer] = {
			goals = goals
		}
	end

	-- fill in goals and cars
	-- goals are overwritten if set here
	for o = 1, MAX_NUM_OPPONENTS do
		for player = 1, MAX_NUM_PLAYERS do
			local participant = participants[o .. "_" .. player] or {}
			local opstring = "opponent" .. o .. "_p" .. player
			local goals = map[opstring .. "goals"]
			local car = map[opstring .. "car"]
			participant.goals = Logic.isEmpty(goals) and participant.goals or goals
			participant.car = Logic.isEmpty(car) and participant.car or car
			if not Table.isEmpty(participant) then
				participants[o .. "_" .. player] = participant
			end
		end
	end

	map.participants = participants
	return map
	end

	--
	-- opponent related functions
	--
	function opponentFunctions.getTeamName(template)
	if template ~= nil then
		local team = Template.expandTemplate(_frame, "Team", { template })
		team = team:gsub("%&", "")
		team = String.split(team, "link=")[2]
		team = String.split(team, "]]")[1]
		return team
	else
		return nil
	end
end

return p
