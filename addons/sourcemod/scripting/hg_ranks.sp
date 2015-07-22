#include <sourcemod>

#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) )

enum PlayerStats
{
	pKills,
	pDeaths,
	pWins,
	pKillStreak
}

new PlayerInfo[MAXPLAYERS+1][PlayerStats];
new SessionInfo[MAXPLAYERS+1][PlayerStats];

new PlayerKillStreaks[MAXPLAYERS+1];
new Handle:hDatabase = INVALID_HANDLE;

public OnPluginStart()
{
	HookEvent("player_death", Event_OnPlayerDeath);
	RegConsoleCmd("sm_session", Event_SessionCallBack);

	MySQL_Init();
}

public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if( !IsValidClient(attacker) || !IsValidClient(victim) )
		return;

	PlayerInfo[attacker][pKills] ++;
	PlayerInfo[attacker][pDeaths] ++;

	PlayerKillStreaks[victim] = 0;
	PlayerKillStreaks[attacker] ++;
	if(PlayerKillStreaks[attacker] > PlayerInfo[attacker][pKillStreak])
		PlayerInfo[attacker][pKillStreak] = PlayerKillStreaks[attacker];
}

public OnClientPostAdminCheck(client)
{
	if(IsValidClient(client))
		LoadData(client);

	CreateSession(client);
}

public OnClientDisconnect(client)
{
	if(IsValidClient(client))
		SaveData(client)

	PlayerKillStreaks[client] = 0;
}

public CreateSession(client)
{
	SessionInfo[client][pKills] = PlayerInfo[client][pKills];
	SessionInfo[client][pDeaths] = PlayerInfo[client][pDeaths];
	SessionInfo[client][pWins] = PlayerInfo[client][pWins];
	SessionInfo[client][pKillStreak] = PlayerInfo[client][pKillStreak];

	PrintToChat(client, "HG-Stats: Your session has been created, !session to view this sessions stats");

}

public Action:Event_SessionCallBack(client, args)
{
	decl String:szItems[60];
	Format(szItems, sizeof( szItems ), "%N's Session", client );

	decl String:szItems3[60];
	Format(szItems3, sizeof( szItems3 ), "Kills %d -> %d", SessionInfo[client][pKills], PlayerInfo[client][pKills] );

	decl String:szItems4[60];
	Format(szItems4, sizeof( szItems4 ), "Deaths %d -> %d", SessionInfo[client][pDeaths], PlayerInfo[client][pDeaths] );

	decl String:szItems5[60];
	Format(szItems5, sizeof( szItems5 ), "Wins %d -> %d", SessionInfo[client][pWins], PlayerInfo[client][pWins]);

	decl String:szItems6[60];
	Format(szItems6, sizeof( szItems6 ), "Kill Streak %d -> %d", SessionInfo[client][pKillStreak], PlayerInfo[client][pKillStreak] );

	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, szItems );
	DrawPanelItem(panel, szItems3, ITEMDRAW_RAWLINE);
 	DrawPanelItem(panel, szItems4, ITEMDRAW_RAWLINE);
	DrawPanelItem(panel, szItems5, ITEMDRAW_RAWLINE);
 	DrawPanelItem(panel, szItems6, ITEMDRAW_RAWLINE);

 	SendPanelToClient(panel, client, PanelHandler1, 3);
 			
 	CloseHandle(panel);	
}

public PanelHandler1(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		CloseHandle(panel);
	}
}

public MySQL_Init()
{
	new String:Error[255];
	decl String:TQuery[512];

	hDatabase = SQL_DefConnect( Error, sizeof(Error) )

	Format( TQuery, sizeof( TQuery ), "CREATE TABLE IF NOT EXISTS `hg_stats` ( `player_id` varchar(32) NOT NULL,`player_name` varchar(32) NOT NULL,`player_kills` int(16) default NULL,`player_deaths` int(16) default NULL,`player_wins` int(16) default NULL, `player_killstreak` int(16) default NULL,PRIMARY KEY (`player_id`) ) TYPE=MyISAM;" );

	if ( hDatabase == INVALID_HANDLE )
	{
		PrintToServer("Failed to connect: %s", Error)
		LogError( "%s", Error ); 
	}

	SQL_TQuery( hDatabase, QueryCreateTable, TQuery);	
}

public QueryCreateTable( Handle:owner, Handle:hndl, const String:error[], any:data)
{ 
	if ( hndl == INVALID_HANDLE )
	{
		LogError( "%s", error ); 
		
		return;
	} 
}


public SaveData(client)
{
	decl String:szQuery[ 256 ]; 
	
	decl String:szKey[64];
	GetClientAuthString( client, szKey, sizeof(szKey) );
	
	Format( szQuery, sizeof( szQuery ), "REPLACE INTO `hg_stats` (`player_id`, `player_name`, `player_kills`, `player_deaths`, `player_wins`,`player_killstreak`) VALUES ('%s', '%N', '%d', '%d', '%d', '%d';", szKey , client, PlayerInfo[client][pKills], PlayerInfo[client][pDeaths],PlayerInfo[client][pWins],PlayerInfo[client][pKillStreak]);
	
	SQL_TQuery( hDatabase, QuerySetData, szQuery, client)
}

public QuerySetData( Handle:owner, Handle:hndl, const String:error[], any:data)
{ 
	if ( hndl == INVALID_HANDLE )
	{
		LogError( "%s", error ); 
		
		return;
	} 
} 

public LoadData(client)
{
	decl String:szQuery[ 256 ]; 
	
	decl String:szKey[64];
	GetClientAuthString( client, szKey, sizeof(szKey) );
	
	Format( szQuery, sizeof( szQuery ), "SELECT `player_kills`, `player_deaths`, `playwe_wins`, `player_killstreak` FROM `hg_stats` WHERE ( `player_id` = '%s' );", szKey );
	
	SQL_TQuery( hDatabase, QuerySelectData, szQuery, client)
}

public QuerySelectData( Handle:owner, Handle:hndl, const String:error[], any:data)
{ 
	if ( hndl != INVALID_HANDLE )
	{
		while ( SQL_FetchRow(hndl) ) 
		{
			PlayerInfo[data][pKills] 			= SQL_FetchInt(hndl, 0);
			PlayerInfo[data][pDeaths] 			= SQL_FetchInt(hndl, 1);
			PlayerInfo[data][pWins] 			= SQL_FetchInt(hndl, 2);
			PlayerInfo[data][pKillStreak] 		= SQL_FetchInt(hndl, 3);
		}
	} 
	else
	{
		LogError( "%s", error ); 
		
		return;
	}
}