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

new const KILL_MULTIPLIER = 10;
new const PLAYER_MULTIPLIER = 5;
new const PLAYER_START_MONEY = 0; // TODO: Raise once money can be earned and spent.

new const PLAYER_RESPAWN_TIME = 3000;

new Float:spawns[][] = {{2054.5679,-1804.4639,14.8501,269.5925},
						{-1713.6855,1199.7866,25.1272,179.3454},
						{2160.5466,2030.8363,10.8203,136.7463}};

new vehicles[] = {462, // Vespa
				  404, // Skruttkombi
				  447}; // Helikopter
				  
//List of players logged in to the server.
new loggedInPlayers[20] = {-1, ...}; 

new survivor = 0; // Player ID of current survivor.
new survivor_points = 0;
new survivor_pps = 0; // Points per second.
new survivor_kills = 0;
               
new mysql; // Handle for the MySQL connection.

// TEXT DRAWS
new Text:curSurvivor;
new Text:survivalStats;
new Text:ranking;
new Text:wasted;

// DIALOG ID'S
new HIGHSCORE_DIALOG = 1;
new REGISTRATION_DIALOG = 2;
new LOGIN_DIALOG = 3;

forward giveSurvivorPoints();
forward showSurvivorStats(playerid);
forward updateTextDraws();
forward spawn(playerid, newPlayer);
forward OnPlayerPersisted(playerid);

main()
{
	print("\n----------------------------------");
	print(" Survival Instinct by Pontus        ");
	print("----------------------------------\n");
}

public OnGameModeInit()
{
	SetGameModeText("Survival Instinct");
	SetWeather(0);
	mysql = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASS);
    initTextDraws();
	
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(0);

	SetTimer("giveSurvivorPoints", 1000, true);
}

public OnPlayerConnect(playerid)
{
	showLoginScreen(playerid);

 	new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

	if(userExists(name))
	{
    	ShowPlayerDialog(playerid, LOGIN_DIALOG, DIALOG_STYLE_INPUT,
			"Log in",
			"Enter the password associated with this account.",
			"Submit", "");
	}
	else
	{
	    ShowPlayerDialog(playerid, REGISTRATION_DIALOG, DIALOG_STYLE_INPUT,
 			"Register",
			"To store your information (score, money etc.) an account is needed.\nPlease enter a password for your new account.",
			"Submit", "");
	}

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	remove(playerid, loggedInPlayers);
	persistPlayerStats(playerid);

    new name[MAX_PLAYER_NAME], string[36 + MAX_PLAYER_NAME];
   	GetPlayerName(playerid, name, sizeof(name));

	if(playerid == survivor)
	{
	    persistRun(playerid);
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

public OnPlayerSpawn(playerid)
{
 	TogglePlayerSpectating(playerid, false);
	setupMapIcons();

	TextDrawHideForPlayer(playerid, wasted);

    if(playerid != survivor) { GivePlayerWeapon(playerid, 46, 0); }
    TogglePlayerControllable(playerid, true);
	return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid, bodypart)
{
	new Float:HP;
	GetPlayerHealth(playerid, HP);
	SetPlayerHealth(playerid, HP - amount);
}

public OnPlayerDeath(playerid, killerid, reason)
{
	//GivePlayerMoney(playerid, -100);
	persistPlayerStats(playerid);

	new Float:x, Float:y, Float:z;

	GetPlayerPos(playerid, x, y, z);
	CreateExplosion(x, y, z, 2, (survivor_points / 1000) + 1);

	TextDrawShowForPlayer(playerid, wasted);

	if(playerid == survivor)
	{
	    persistRun(playerid);

		if(killerid != INVALID_PLAYER_ID) { turnIntoSurvivor(killerid); }
		else { pickNewSurvivor(); }
	}

	if(killerid == survivor) survivor_kills++;

	TogglePlayerSpectating(playerid, true);
	SetTimerEx("spawn", PLAYER_RESPAWN_TIME, false, "ib", playerid, false);
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	if (!strcmp(cmdtext, "/v", true, 2)) {
	    return spawnVehicle(playerid, vehicles[min(sizeof(vehicles) - 1, survivor_points / 1000)]);
	} else if (!strcmp(cmdtext, "/killme", true, 7)) {
	    return SetPlayerHealth(playerid, 0);
	} else if (!strcmp(cmdtext, "/hs", true, 3)) {
		return showHighScores(playerid);
	} else if (!strcmp(cmdtext, "/r", true, 2)) {
	    return repair(playerid);
	} else if (!strcmp(cmdtext, "/skin", true, 5)) {
	    return SetPlayerSkin(playerid, random(311));
	}

	return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

	if(response)
	{
		switch(dialogid)
		{
		    case 2: //REGISTRATION DIALOG
		    {
		        if(strlen(inputtext) >= 4)
				{
		        	persistPlayer(name, inputtext);
		        	enterGame(playerid, true);
				}
				else
				{
                    ShowPlayerDialog(playerid, REGISTRATION_DIALOG, DIALOG_STYLE_INPUT,
		 				 "Register",
						 "Your password needs to be at least 4 characters long.",
						 "Submit", "");
				}
			}
		    case 3: //LOGIN DIALOG
		    {
				if(login(name, inputtext))
				{
				    enterGame(playerid, false);
				}
				else
				{
				    ShowPlayerDialog(playerid, LOGIN_DIALOG, DIALOG_STYLE_INPUT,
		 				 "Log in",
						 "Incorrect password. Enter the password associated with this account.",
						 "Submit", "");
				}
		    }
		}
	}
}

public giveSurvivorPoints()
{
	new players = countLoggedInPlayers();

	if(players > 0)
	{
		survivor_pps = (players - 1) * PLAYER_MULTIPLIER + (survivor_kills * KILL_MULTIPLIER);
		survivor_points += survivor_pps;
	}
}

public showSurvivorStats(playerid)
{
    TextDrawShowForPlayer(playerid, survivalStats);
	TextDrawShowForPlayer(playerid, curSurvivor);
	TextDrawShowForPlayer(playerid, ranking);
}

public spawn(playerid, newPlayer)
{
	new Float:sx, Float:sy, Float:sz, Float:sa;
	new playerSkinID = (newPlayer) ? random(311) : retrievePlayerInt(playerid, "skin");

	if(playerid != survivor)
	{
	    GetPlayerPos(survivor, sx, sy, sz);
	    GetPlayerFacingAngle(survivor, sa);
	    SetSpawnInfo(playerid, 0, playerSkinID, sx, sy, sz + 400, sa,
                     29, 200, 31, 1000, 24, 42);
	}
	else
	{
		new rl = random(sizeof(spawns));
    	SetSpawnInfo(playerid, 0, playerSkinID,
    				 spawns[rl][0], spawns[rl][1], spawns[rl][2], spawns[rl][3],
					 29, 200, 31, 1000, 24, 42);
	}
	SpawnPlayer(playerid);
    return 1;
}

retrievePlayerInt(playerid, field[])
{
    new name[MAX_PLAYER_NAME], query[128];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	format(query, sizeof(query), "SELECT %s FROM `players` WHERE name = '%s'", field, name);

	new Cache:c = mysql_query(mysql, query);
	new value = cache_get_field_content_int(0, field);
	cache_delete(c);

	return value;
}

public updateTextDraws()
{
    new nameBuf[MAX_PLAYER_NAME],
        csBuf[MAX_PLAYER_NAME + 18],
        sBuf[100],
		rBuf[24];

	GetPlayerName(survivor, nameBuf, sizeof(nameBuf));
	format(csBuf, sizeof(csBuf), "Current survivor: %s", nameBuf);
	format(sBuf, sizeof(sBuf), "Score: %d - PPS: %d - Kills: %d",
		   survivor_points, survivor_pps, survivor_kills);
	format(rBuf, sizeof(rBuf), "Ranking: %d", getRanking());

	TextDrawSetString(curSurvivor, csBuf);
	TextDrawSetString(survivalStats, sBuf);
	TextDrawSetString(ranking, rBuf);
}

getRanking()
{
	new query[128];

	format(query, sizeof(query),
           "SELECT points FROM `records` WHERE points > %d", survivor_points);

    new Cache:records = mysql_query(mysql, query);
	new rows = cache_num_rows();
	cache_delete(records);
	
	return rows + 1;
}

countLoggedInPlayers() {
	new count = 0;

	for(new i = 0; i < MAX_PLAYERS; i++)
	{
	    if(loggedInPlayers[i] != -1) count++;
	}
	
	return count;
}

findEmptySlot(array[], len = sizeof(array))
{
	new i = 0;
	while(i < len && array[i] != -1)
	{
	    i++;
	}
	return i;
}

remove(element, array[], len = sizeof(array))
{
	for(new i = 0; i < len; i++)
	{
	    if(array[i] == element)
		{
			array[i] = -1;
			return true;
		}
	}
	
	return false;
}

showLoginScreen(playerid)
{
   	SetSpawnInfo(playerid, 0, 0, 0, 0, 0, 0,
				 29, 200, 31, 1000, 24, 42);
	SpawnPlayer(playerid);

	SetPlayerCameraPos(playerid, -2504.9888,2211.3877,4.9844);
	SetPlayerCameraLookAt(playerid, -2656.4832,1454.5568,67.4726);
	
    return 1;
}

persistPlayer(name[], password[])
{
	new query[100];
	mysql_format(mysql, query, sizeof(query),
		"INSERT INTO `players` (name, password) VALUES ('%s', '%s')",
		name, password);
	mysql_pquery(mysql, query);
		
	return 1;
}

persistPlayerStats(playerid)
{
    new name[MAX_PLAYER_NAME], query[128];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new skin = GetPlayerSkin(playerid);
	new money = GetPlayerMoney(playerid);

	mysql_format(mysql, query, sizeof(query),
		"UPDATE players SET `money` = %d, `skin` = %d WHERE name = '%s'",
		money, skin, name);
	mysql_pquery(mysql, query);
	
	return 1;
}

login(name[], password[])
{
	new dbPassword[64];
	getUserPassword(name, dbPassword);
	
	if(strcmp(password, dbPassword, false, sizeof(dbPassword)) == 0 &&
	   strlen(password) != 0)
	{
	    return true;
	}
	
	return false;
}

getUserPassword(name[], dbPassword[64])
{
    new query[100];
	format(query, sizeof(query),
           "SELECT password FROM `players` WHERE name = '%s'", name);
	new Cache:pw = mysql_query(mysql, query);
	cache_get_field_content(0, "password", dbPassword);
	cache_delete(pw);
}

enterGame(playerid, newPlayer)
{
	if(newPlayer)
	{
	    GivePlayerMoney(playerid, PLAYER_START_MONEY);
	}
	else
	{
	    GivePlayerMoney(playerid, retrievePlayerInt(playerid, "money"));
	}

    new name[MAX_PLAYER_NAME], string[24 + MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    
    format(string, sizeof(string), "%s has entered the game.", name);
    SendClientMessageToAll(GREEN, string);
    
    spawn(playerid, newPlayer);

	SetTimerEx("showSurvivorStats", 1000, false, "i", playerid);
    loggedInPlayers[findEmptySlot(loggedInPlayers)] = playerid;
    
    return 1;
}

pickNewSurvivor()
{
	new tries = countLoggedInPlayers() * 1000;

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

turnIntoSurvivor(playerid)
{
 	resetSurvivorStats();
	survivor = playerid;
}

resetSurvivorStats()
{
	survivor_points = survivor_pps = survivor_kills = 0;
}

setupMapIcons()
{
	for(new p = 0; p < MAX_PLAYERS; p++)
	{
		for(new q = 0; q < MAX_PLAYERS; q++)
		{
		    if(p != q)
		    {
		        if(p == survivor)
		        {
					SetPlayerMarkerForPlayer(p, q, RED);
				}
				else
				{
				    if(q == survivor)
				    {
				        SetPlayerMarkerForPlayer(p, q, RED);
					}
					else {
					    SetPlayerMarkerForPlayer(p, q, CLEAR);
					}
				}
		    }
		}
	}
}

repair(playerid)
{
    if(IsPlayerInAnyVehicle(playerid))
	{
		RepairVehicle(GetPlayerVehicleID(playerid));
	}

	return 1;
}

spawnVehicle(playerid, type)
{
    new Float:x, Float:y, Float:z, Float:angle;

    GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, angle);
	new vid = CreateVehicle(type, x, y, z, angle, random(255), random(255), -1);
	PutPlayerInVehicle(playerid, vid, 0);
	return 1;
}

userExists(name[])
{
	new query[100];
	format(query, sizeof(query), "SELECT * FROM `players` WHERE `name` = '%s'",
	       name);
	new Cache:c = mysql_query(mysql, query);
	new rows = cache_num_rows();
	cache_delete(c);

	return (rows > 0);
}

persistRun(playerid)
{
	if(survivor_points > 0)
	{
		new query[200];
		new playerName[MAX_PLAYER_NAME];
		GetPlayerName(playerid, playerName, sizeof(playerName));

		format(query, sizeof(query),
	           "INSERT INTO records (player, points, kills, pps) VALUES ('%s', %d, %d, %d)",
	           playerName, survivor_points, survivor_kills, survivor_pps);

		mysql_pquery(mysql, query);
	}
	return 1;
}

showHighScores(playerid)
{
	new dialogStr[1024] = "Player\tScore\tKills\n";

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
	
	ShowPlayerDialog(playerid, HIGHSCORE_DIALOG, DIALOG_STYLE_TABLIST_HEADERS,
					 "High Scores", dialogStr, "Close", "");
					 
	return 1;
}

initTextDraws()
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
	
	ranking = TextDrawCreate(320, 405, "");
	TextDrawFont(ranking, 2);
	TextDrawLetterSize(ranking, 0.4, 1.5);
	TextDrawColor(ranking, GRAY);
	TextDrawSetOutline(ranking, 1);
	TextDrawSetProportional(ranking, true);
	TextDrawSetShadow(ranking, 1);
	TextDrawAlignment(ranking, 2);
	
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

