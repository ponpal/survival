#include <a_samp>
#include <a_mysql>

#undef MAX_PLAYERS
#define MAX_PLAYERS 20

#define MYSQL_HOST "localhost"
#define MYSQL_USER "root"
#define MYSQL_DB "survival"
#define MYSQL_PASS ""

#define RED   0xFF4444FF
#define GREEN 0x44FF44FF
#define WHITE 0xFFFFFFFF
#define GRAY  0xCCCCCCFF
#define CLEAR 0xFFFFFF00

new const KILL_MULTIPLIER = 3;
new const PLAYER_MULTIPLIER = 1;

new Float:spawns[][] = {{2459.2466,-1687.6827,13.5363,274.7917},
						{2495.4873,-1688.2413,13.6832,5.0324},
						{2522.0808,-1678.9684,15.4970,83.9932},
						{2066.8889,-1703.4855,14.1484,273.0428},
						{369.8315,-2048.7153,7.8359,359.5844},
						{408.1158,-1542.1617,32.2734,221.7613},
						{701.9957,-1699.7651,3.4115,267.8530},
						{1209.3223,-2037.0942,69.0078,269.2162},
						{1589.2742,-1506.8772,37.7846,283.1582},
                        {2252.5283,-1030.8892,56.4141,225.2408},
                        {533.3042,-1040.1722,91.4593,256.5341},
                        {2413.7227,-2142.1038,13.5469,0.0344},
                        {2832.4485,-1183.5514,24.7749,270.2657},
                        {2439.2061,-970.6992,79.8092,100.1898}};

new players = 0;

new survivor = 0; // Player ID of current survivor.
new survivor_points = 0;
new survivor_pps = 0; // Points per second.
new survivor_kills = 0;
               
new mysql; // Handle for the MySQL connection.

// TEXT DRAWS
new Text:curSurvivor;
new Text:survivalStats;
new Text:wasted;

// DIALOG ID'S
new HIGHSCORE_DIALOG_ID = 1;

forward giveSurvivorPoints();
forward initTextDraws();
forward pickNewSurvivor();
forward repair(playerid);
forward resetSurvivorStats();
forward setupMapIcons(playerid);
forward showDeathMessage(playerid, message, color);
forward showHighScores(playerid);
forward showScoreboard(playerid);
forward showSurvivorStats(playerid);
forward spawn(playerid);
forward spawnVehicle(playerid, type);
forward storeRun(playerid);
forward turnIntoSurvivor(playerid);
forward updateTextDraws();

main()
{
	print("\n----------------------------------");
	print(" Survival Instinct by Pontus        ");
	print("----------------------------------\n");
}

public OnGameModeInit()
{
	SetGameModeText("Survival Instinct");
	mysql = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASS);
    initTextDraws();
	
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(0);

	SetTimer("giveSurvivorPoints", 1000, true);
}

public giveSurvivorPoints()
{
	if(players > 0)
	{
		survivor_pps = (players - 1) * PLAYER_MULTIPLIER *
	    	           (1 + survivor_kills * KILL_MULTIPLIER);
		survivor_points += survivor_pps;
	}
}

public OnPlayerConnect(playerid)
{
	players++;

	new name[MAX_PLAYER_NAME], string[24+MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    format(string, sizeof(string), "%s has joined the server. (%d)",
		   name, playerid);
    SendClientMessageToAll(GREEN, string);

    spawn(playerid);

	SetTimerEx("showSurvivorStats", 1000, false, "i", playerid);

    return 1;
}

public showSurvivorStats(playerid)
{
    TextDrawShowForPlayer(playerid, survivalStats);
	TextDrawShowForPlayer(playerid, curSurvivor);
}

public OnPlayerDisconnect(playerid, reason)
{
	players--;

    new name[MAX_PLAYER_NAME], string[36 + MAX_PLAYER_NAME];
   	GetPlayerName(playerid, name, sizeof(name));

	if(playerid == survivor)
	{
	    storeRun(playerid);
		format(string, sizeof(string), "The survivor (%s) has left the server.", name);
		SendClientMessageToAll(RED, string);
 		pickNewSurvivor();
 		return 1;
	} else {
	    format(string, sizeof(string), "%s has left the server.", name);
    	SendClientMessageToAll(RED, string);
		return 1;
	}
}

public spawn(playerid)
{
	new randomSkinID = random(299);
	new rl = random(sizeof(spawns));
	new Float:sx, Float:sy, Float:sz, Float:sa;

	if(playerid != survivor)
	{
	    GetPlayerPos(survivor, sx, sy, sz);
	    GetPlayerFacingAngle(survivor, sa);
	    SetSpawnInfo(playerid, 0, randomSkinID, sx, sy, 400, sa,
                     29, 200, 31, 1000, 24, 42);
	}
	else
	{
    	SetSpawnInfo(playerid, 0, randomSkinID,
    				 spawns[rl][0], spawns[rl][1], spawns[rl][2], spawns[rl][3],
					 29, 200, 31, 1000, 24, 42);
	}
	SpawnPlayer(playerid);

    return 1;
}

public pickNewSurvivor()
{
	new tries = players * 1000;

	for(new i = 0; i < tries; i++)
	{
	    new id = random(MAX_PLAYERS);
        if(IsPlayerConnected(id) && id != survivor)
		{
			turnIntoSurvivor(id);
			return 1;
  		}
  		i++;
	}

	survivor = 0; // No player was found, resetting.
	resetSurvivorStats();
	return 1;
}

public turnIntoSurvivor(playerid)
{
 	resetSurvivorStats();

	survivor = playerid;

    new name[MAX_PLAYER_NAME], string[30+MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    format(string, sizeof(string), "%s (%d) is the new survivor!", name, playerid);
 	SendClientMessageToAll(WHITE, string);
}

public resetSurvivorStats()
{
	survivor_points = 0;
	survivor_pps = 0;
	survivor_kills = 0;
}

public OnPlayerSpawn(playerid)
{
 	TogglePlayerSpectating(playerid, false);
	setupMapIcons(playerid);

	TextDrawHideForPlayer(playerid, wasted);

    if(playerid != survivor) { GivePlayerWeapon(playerid, 46, 0); }
    TogglePlayerControllable(playerid, true);
	return 1;
}

public setupMapIcons(playerid)
{
	for(new p = 0; p < MAX_PLAYERS; p++)
	{
	    if(playerid == survivor)
	    {
	        if(IsPlayerConnected(p))
			{
		    	SetPlayerMarkerForPlayer(p, playerid, RED);
			}
	    }
	    else {
			if(p == survivor)
			{
			    SetPlayerMarkerForPlayer(p, playerid, RED);
   			}
   			else
   			{
   			    SetPlayerMarkerForPlayer(p, playerid, CLEAR);
   			}
		}
	}
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart)
{
	new Float:HP;
	GetPlayerHealth(playerid, HP);
	SetPlayerHealth(playerid, HP - (amount * 2));
}

public OnPlayerDeath(playerid, killerid, reason)
{
	new Float:x, Float:y, Float:z;

	GetPlayerPos(playerid, x, y, z);
	CreateExplosion(x, y, z, 12, 2.0);

	TextDrawShowForPlayer(playerid, wasted);

	if(playerid == survivor)
	{
	    storeRun(playerid);
	    
		if(killerid != INVALID_PLAYER_ID) { turnIntoSurvivor(killerid); }
		else { pickNewSurvivor(); }
	}
	
	if(killerid == survivor) survivor_kills++;
	
	TogglePlayerSpectating(playerid, true);
	SetTimerEx("spawn", 3000, false, "i", playerid);
	return 1;
}

public repair(playerid)
{
    if(IsPlayerInAnyVehicle(playerid))
	{
		RepairVehicle(GetPlayerVehicleID(playerid));
	}

	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/car", true, 4)) {
		return spawnVehicle(playerid, 411);
	} else if (!strcmp(cmdtext, "/bike", true, 5)) {
		return spawnVehicle(playerid, 522);
	} else if (!strcmp(cmdtext, "/boat", true, 5)) {
		return spawnVehicle(playerid, 454);
	} else if (!strcmp(cmdtext, "/heli", true, 5)) {
		return spawnVehicle(playerid, 425);
	} else if (!strcmp(cmdtext, "/killme", true, 7)) {
	    return SetPlayerHealth(playerid, 0);
	} else if (!strcmp(cmdtext, "/hs", true, 3)) {
		return showHighScores(playerid);
	} else if (!strcmp(cmdtext, "/r", true, 2)) {
	    return repair(playerid);
	} else if (!strcmp(cmdtext, "/skin", true, 5)) {
	    return SetPlayerSkin(playerid, random(299));
	}
	
	return 0;
}

public spawnVehicle(playerid, type)
{
    new Float:x, Float:y, Float:z, Float:angle;

    GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, angle);
	new vid = CreateVehicle(type, x, y, z, angle, random(255), random(255), -1);
	PutPlayerInVehicle(playerid, vid, 0);
	return 1;
}

public storeRun(playerid)
{
	if(survivor_points > 0)
	{
		new query[200];
		new playerName[MAX_PLAYER_NAME];
		GetPlayerName(playerid, playerName, sizeof(playerName));

		format(query, sizeof(query),
	           "INSERT INTO records (player, points, kills, pps) VALUES ('%s', %d, %d, %d)",
	           playerName, survivor_points, survivor_kills, survivor_pps);

		mysql_query(mysql, query);
	}
	return 1;
}

public showHighScores(playerid)
{
	new dialogStr[1024] = "Player\tPoints\tKills\n";

	new Cache:records =
		mysql_query(mysql,
		            "SELECT * FROM `records` ORDER BY `points` DESC LIMIT 10");
	new rows = cache_num_rows();
	new iterations = min(rows, 10);
	
	for(new i = 0; i < iterations; i++)
	{
	    new rowStr[MAX_PLAYER_NAME + 20];
	    new player[MAX_PLAYER_NAME];
		cache_get_field_content(i, "player", player);
		new points = cache_get_field_content_int(i, "points");
		new kills = cache_get_field_content_int(i, "kills");
		
		if(i == iterations - 1)
		{
		    format(rowStr, sizeof(rowStr), "%s\t%d\t%d", player, points, kills);
		}
		else
		{
		    format(rowStr, sizeof(rowStr), "%s\t%d\t%d\n", player, points, kills);
		}
		
		strcat(dialogStr, rowStr);
	}
	
	cache_delete(records);
	
	ShowPlayerDialog(playerid, HIGHSCORE_DIALOG_ID, DIALOG_STYLE_TABLIST_HEADERS,
					 "High Scores", dialogStr, "Close", "");
					 
	return 1;
}

public initTextDraws()
{
    curSurvivor = TextDrawCreate(320, 365, "");
	TextDrawFont(curSurvivor, 2);
	TextDrawLetterSize(curSurvivor, 0.4, 1.5);
	TextDrawColor(curSurvivor, WHITE);
	TextDrawSetOutline(curSurvivor, 1);
	TextDrawSetProportional(curSurvivor, true);
	TextDrawSetShadow(curSurvivor, 1);
	TextDrawAlignment(curSurvivor, 2);
	
	survivalStats = TextDrawCreate(320, 385, "");
	TextDrawFont(survivalStats, 2);
	TextDrawLetterSize(survivalStats, 0.4, 1.5);
	TextDrawColor(survivalStats, GRAY);
	TextDrawSetOutline(survivalStats, 1);
	TextDrawSetProportional(survivalStats, true);
	TextDrawSetShadow(survivalStats, 1);
	TextDrawAlignment(survivalStats, 2);
	
	wasted = TextDrawCreate(320, 200, "Wasted");
	TextDrawFont(wasted, 2);
	TextDrawLetterSize(wasted, 0.8, 1.8);
	TextDrawColor(wasted, WHITE);
	TextDrawSetOutline(wasted, 1);
	TextDrawSetProportional(wasted, true);
	TextDrawSetShadow(wasted, 1);
	TextDrawAlignment(wasted, 2);
	
	SetTimer("updateTextDraws", 1000, true);
}

public updateTextDraws()
{
    new nameBuf[MAX_PLAYER_NAME],
        csBuf[MAX_PLAYER_NAME + 18],
        sBuf[100];

	GetPlayerName(survivor, nameBuf, sizeof(nameBuf));
	format(csBuf, sizeof(csBuf), "Current survivor: %s", nameBuf);
	format(sBuf, sizeof(sBuf), "Points: %d - PPS: %d - Kills: %d",
		   survivor_points, survivor_pps, survivor_kills);
		   
	TextDrawSetString(curSurvivor, csBuf);
	TextDrawSetString(survivalStats, sBuf);
}
