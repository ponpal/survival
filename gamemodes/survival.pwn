#include <a_samp>
#include <a_mysql>

#undef MAX_PLAYERS
#define MAX_PLAYERS 20

#define MYSQL_HOST "localhost"
#define MYSQL_USER "root"
#define MYSQL_DB "survival"
#define MYSQL_PASS ""

new const KILL_MULTIPLIER = 3;

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

forward initTextDraws();
forward pickNewSurvivor();
forward turnIntoSurvivor(playerid);
forward spawn(playerid);
forward giveSurvivorPoints();
forward spawnVehicle(playerid, type);
forward ConnectMySQL();
forward showScoreboard(playerid);
forward setupMapIcons(playerid);
forward storeRun(playerid);
forward resetSurvivorStats();
forward showDeathMessage(playerid, message, color);
forward updateTextDraws();
forward showHighScores(playerid);

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

	SetTimer("giveSurvivorPoints", 1000, true);
}

public giveSurvivorPoints()
{
	if(players > 0)
	{
		survivor_pps = (players - 1) *
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
    SendClientMessageToAll(0x44FF44FF, string);

    spawn(playerid);

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	players--;

	if(playerid == survivor)
	{
	    storeRun(playerid);
		SendClientMessageToAll(0xFF4444FF, "The survivor has left the server.");
 		pickNewSurvivor();
 		return 1;
	} else {
	    new name[MAX_PLAYER_NAME], string[24 + MAX_PLAYER_NAME];
    	GetPlayerName(playerid, name, sizeof(name));

	    format(string, sizeof(string), "%s has left the server.", name);
    	SendClientMessageToAll(0xFF4444FF, string);

		return 1;
	}
}

public spawn(playerid)
{
	new randomSkinID = random(299);

    SetSpawnInfo(playerid, 0, randomSkinID,
		             2066.8889, -1703.4855, 14.1484, 273.0428,
					 29, 200, 31, 1000, 24, 42);
	SpawnPlayer(playerid);

    return 1;
}

public pickNewSurvivor()
{
	new tries = players * 10;

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
	return 1;
}

public turnIntoSurvivor(playerid)
{
	resetSurvivorStats();

	survivor = playerid;

    new name[MAX_PLAYER_NAME], string[30+MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    format(string, sizeof(string), "%s (%d) is the new survivor!", name, playerid);
 	SendClientMessageToAll(0xFFFFFFFF, string);
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
    TextDrawShowForPlayer(playerid, curSurvivor);
	TextDrawShowForPlayer(playerid, survivalStats);
	
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
		    	SetPlayerMarkerForPlayer(p, playerid, 0xE81010FF);
			}
	    }
	    else {
			if(p == survivor)
			{
			    SetPlayerMarkerForPlayer(p, playerid, 0xE81010FF);
   			}
   			else
   			{
   			    SetPlayerMarkerForPlayer(p, playerid, 0xFFFFFF00);
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

	storeRun(playerid);

    TextDrawHideForPlayer(playerid, curSurvivor);
	TextDrawHideForPlayer(playerid, survivalStats);
	TextDrawShowForPlayer(playerid, wasted);

	if(playerid == survivor)
	{
		if(killerid != INVALID_PLAYER_ID)
		{
			turnIntoSurvivor(killerid);
		}
		else
		{
		    pickNewSurvivor();
		}
	}
	
	if(killerid == survivor) survivor_kills++;
	
	TogglePlayerSpectating(playerid, true);
	SetTimerEx("spawn", 3000, false, "i", playerid);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (strcmp("/car", cmdtext, true, 10) == 0)
	{
		spawnVehicle(playerid, 411);
		return 1;
	}
	else if (strcmp("/bike", cmdtext, true, 10) == 0)
	{
	    spawnVehicle(playerid, 522);
	    return 1;
	}
	else if (strcmp("/boat", cmdtext, true, 10) == 0)
	{
	    spawnVehicle(playerid, 454);
	    return 1;
	}
	else if (strcmp("/heli", cmdtext, true, 10) == 0)
	{
	    spawnVehicle(playerid, 425);
	    return 1;
	}
	else if (strcmp("/killme", cmdtext, true, 10) == 0)
	{
	    SetPlayerHealth(playerid, 0);
	    return 1;
 	}
 	else if (strcmp("/hs", cmdtext, true, 10) == 0)
 	{
 	    showHighScores(playerid);
 	    return 1;
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
					 "High Scores", dialogStr, "Details", "Cancel");
}

public initTextDraws()
{
    curSurvivor = TextDrawCreate(320, 370, "");
	TextDrawFont(curSurvivor, 2);
	TextDrawLetterSize(curSurvivor, 0.4, 1.5);
	TextDrawColor(curSurvivor, 0xFFFFFFFF);
	TextDrawSetOutline(curSurvivor, 1);
	TextDrawSetProportional(curSurvivor, true);
	TextDrawSetShadow(curSurvivor, 1);
	TextDrawAlignment(curSurvivor, 2);
	
	survivalStats = TextDrawCreate(320, 390, "");
	TextDrawFont(survivalStats, 2);
	TextDrawLetterSize(survivalStats, 0.4, 1.5);
	TextDrawColor(survivalStats, 0xCCCCCCFF);
	TextDrawSetOutline(survivalStats, 1);
	TextDrawSetProportional(survivalStats, true);
	TextDrawSetShadow(survivalStats, 1);
	TextDrawAlignment(survivalStats, 2);
	
	wasted = TextDrawCreate(320, 200, "Wasted");
	TextDrawFont(wasted, 2);
	TextDrawLetterSize(wasted, 0.8, 1.8);
	TextDrawColor(wasted, 0xFFFFFFFF);
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
