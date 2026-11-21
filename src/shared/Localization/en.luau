--!strict
-- English text. Same keys as ko.luau (typed as Ko.Text, so a missing or extra key is a type error).
-- Keep the same format specifiers (%d, %s, %%) in the same order as the Korean source.
-- Game terms (keep consistent): Survivor, Chaser, Spectator, Caught, Escaped, Injured, Spectate,
--   Generator, Exit, Hiding spot, Stamina, Last Survivor, Best Survivor, Coins.

local Ko = require(script.Parent.ko)

local En: Ko.Text = {
	Roles = {
		Survivor = "Survivor",
		Chaser = "Chaser",
		Spectator = "Spectator",
	},

	RoleGoals = {
		Survivor = "Repair all generators and escape, or don't get caught until time runs out!",
		Chaser = "Catch every Survivor before time runs out!",
		Spectator = "Watch the other players until the next stage.",
	},

	SurvivorStates = {
		Normal = "Healthy",
		Injured = "Injured",
		Caught = "Caught",
		Escaped = "Escaped",
	},

	Phases = {
		Waiting = "Waiting",
		RoleReveal = "Role Reveal",
		Preparation = "Get Ready",
		Chase = "Chase",
		StageResult = "Stage Results",
		MatchResult = "Final Results",
	},

	Stages = {
		Stage1 = "Abandoned School",
		Stage2 = "Abandoned Hospital",
		Stage3 = "Underground Lab",
		Stage4 = "Amusement Park",
		Stage5 = "Closed Subway",
	},

	Monsters = {
		Wanderer = "Wanderer",
		Hound = "Hound",
		Watcher = "Watcher",
		Shadow = "Shadow",
		Giant = "Giant",
	},

	Chasers = {
		Hunter = "Hunter",
		Tracker = "Tracker",
		Wraith = "Wraith",
		Puppeteer = "Puppeteer",
	},

	Skills = {
		Dash = "Dash",
		RevealFootprints = "Track",
		Blink = "Blink",
		CallMonsters = "Call Monsters",
	},

	SkillDescriptions = {
		Dash = "For %ds, move speed +%d%%",
		RevealFootprints = "Survivor footprints visible for %ds",
		Blink = "Teleport %d studs where you look (not through walls)",
		CallMonsters = "Call the %d nearest monsters to you",
	},

	Items = {
		Flashlight = "Flashlight",
		Bandage = "Bandage",
		SmokeBomb = "Smoke Bomb",
		AlarmClock = "Alarm Clock",
		EnergyDrink = "Energy Drink",
	},

	Notices = {
		PreparationSurvivor = "Scatter and find a place to hide! The Chaser will be released soon.",
		PreparationSolo = "Scatter and find a place to hide! The monsters will start moving soon.",
		PreparationChaser = "The waiting room door opens soon.",
		ChaserReleased = "The Chaser has been released!",
		SurvivorCaught = "%s was caught.",
		SurvivorEscaped = "%s escaped!",
		ExitOpened = "The exits are open! Escape now!",
		ChaserLeft = "The Chaser left. Only monsters remain this stage.",
		MatchInProgress = "A match is in progress. Please wait in the lobby for the next match.",
		SoloTeleporting = "Moving to a solo server...",
		SoloTeleportFailed = "Couldn't move. Please try again in a moment.",
		SoloStudio = "In Studio, solo play starts on this server.",
		ChaserUnlocked = "%s unlocked!",
		NotEnoughCoins = "Not enough Coins.",
		CoinsPurchased = "You received %d Coins!",
		VipActivated = "You're now VIP! Name color · lobby emote · Coins +20%%",
		MatchMode = "This match is in %s mode.",
	},

	Modes = {
		Night = "Night",
		Casual = "Casual",
	},

	RoleReveal = {
		Choosing = "Choosing the Chaser...",
		ChaserTitle = "This stage's Chaser is",
		YouAreChaser = "You are the Chaser!",
		YouAreSurvivor = "You are a Survivor!",
		Solo = "Solo: no Chaser, only monsters.",
	},

	Prompts = {
		Hide = "Hide",
		Unhide = "Come Out",
		OpenHideSpot = "Search",
		Heal = "Heal",
		Repair = "Repair",
		PickUp = "Pick Up",
		PushPlank = "Push Over",
		OpenDoor = "Open",
		CloseDoor = "Close",
	},

	Hud = {
		WaitingForPlayers = "Waiting for players...",
		StartsIn = "Starts in %ds",
		StageTitle = "Stage %d · %s",
		TimeLeft = "Time Left",
		SurvivorsLeft = "Survivors left: %d",
		Objective = "Generators %d/%d",
		Stamina = "Stamina",
		Attack = "Attack",
		Skill = "Skill",
		Item = "Item",
		Run = "Run",
		Interact = "Interact",
		AttackReady = "Attack ready",
		Repairing = "Repairing %d%%",
		Stunned = "Stunned!",
		Battery = "%s %d%%",
		SkillReady = "%s ready",
		SkillCooldown = "%s %ds",
		ExitOpen = "Exits open!",
		Exit = "EXIT",
		Repaired = "Running",
		Clock = "%d:%02d",
		PhaseClock = "%s %d:%02d",
	},

	Input = {
		KeyAction = "[%s] %s",
		WithKey = "%s  [%s]",
		MouseButton1 = "Click",
		Tap = "Tap",
	},

	Markers = {
		GeneratorNoise = "Generator noise",
		WatcherAlert = "Watcher alert",
	},

	Spectate = {
		Title = "Spectating",
		Previous = "Prev",
		Next = "Next",
		NoTarget = "No players to watch.",
		ReturnToLobby = "Back to Lobby",
		Joined = "%s · %s",
		Hidden = "Hidden",
		KeyHint = "Q·E or ←·→ to switch",
		GamepadHint = "LB·RB to switch",
		ChatPrefix = "[Spectator]",
		ChatNotice = "Spectator chat. Only spectators can see these messages.",
	},

	System = {
		DataLoadFailed = "Couldn't load your data. Please rejoin.",
		DataSessionTaken = "Your data is in use on another server, so you were disconnected. Please rejoin.",
		SoloServerFull = "You can't join a solo server.",
	},

	Lobby = {
		Together = "Play Together",
		Solo = "Play Solo",
		QueueCount = "%d waiting to play together",
		NeedMore = "Need 1 more player",
		SoloServer = "Solo server",
		SoloOfferTitle = "Start solo?",
		SoloOfferBody = "No other players came for %d seconds. Start a solo match with only monsters and no Chaser? (70%% rewards)",
		SoloYes = "Play Solo",
		SoloNo = "Keep Waiting",
		ChaserOptOut = "No Chaser role",
		ChaserSelect = "Choose Chaser",
		Selected = "Selected",
		Select = "Select",
		UnlockCost = "Unlock %d",
		Close = "Close",
		Cooldown = "Cooldown %ds",
		On = "On",
		Off = "Off",
		Coins = "%d Coins",
		Level = "Lv %d",
		Shop = "Shop",
		Emote = "Emote",
		ModeButton = "Mode: %s",
		NextMode = "Next match: %s",
		ModeVotes = "Casual %d · Night %d",
		TogetherHint = "Wait for other players on the green pad",
		SoloHint = "Press [Play Solo] on the blue pad to start right away",
	},

	Shop = {
		Title = "Shop",
		Vip = "VIP",
		VipPerks = "Chat name color · Lobby-only emote · Coins earned +20%",
		Owned = "Owned",
		NotReady = "Coming soon",
		Robux = "R$ %d",
		Buy = "Buy",
		CoinPack = "%d Coins",
		CoinsSection = "Buy Coins",
		ChasersSection = "Unlock Chasers",
		AllUnlocked = "All unlocked",
		Unlock = "%d Coins",
		CosmeticsSection = "Cosmetics",
		CosmeticsSoon = "Survivor and Chaser skins, catch effects (coming soon)",
		VipTag = "VIP",
	},

	Results = {
		StageTitle = "Stage Results",
		MatchTitle = "Final Results",
		ChaserWins = "Chaser wins!",
		SurvivorsWin = "Survivors win!",
		LastSurvivor = "Last Survivor",
		BestSurvivor = "Best Survivor",
		PlayAgain = "Play Again",
		SoloSuccess = "You survived!",
		SoloFail = "You were caught...",
		NoTitle = "Nobody survived to the end this match.",
		Coins = "+%d Coins",
		ChaserCatches = "%d caught",
		ColumnName = "Name",
		ColumnStage = "S%d",
		ColumnCatches = "Catches",
		ColumnCoins = "Coins",
	},

	Outcomes = {
		Survived = "Survived",
		Escaped = "Escaped",
		Caught = "Caught",
		Chaser = "Chaser",
		Left = "Left",
		Absent = "-",
	},
}

return En
