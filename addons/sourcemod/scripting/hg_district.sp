#include <sourcemod>
#include <cstrike>
#include <smlib>
#include <sdkhooks>

new district[MAXPLAYERS+1]

enum {
	NONE,
	DISTRICTONE,
	DISTRICTTWO,
	DISTRICTTHREE,
	DISTRICTFOUR,
	DISTRICTFIVE,
	DISTRICTSIX,
	DISTRICTSEVEN,
	DISTRICTEIGHT,
	DISTRICTNINE,
	DISTRICTTEN,
	DISTRICTELEVEN,
	DISTRICTTWELVE
}

new const String:district_list[][] = 
{
	"District None",
	"District 1",
	"District 2",
	"District 3",
	"District 4",
	"District 5",
	"District 6",
	"District 7",
	"District 8",
	"District 9",
	"District 10",
	"District 11",
	"District 12",
}

public OnPluginStart()
{
	HookEvent("player_spawn", EventHook_PlayerSpawn)

	RegConsoleCmd("sm_district", Command_DistrictMenu, "District Menu")
}

public Action:Command_DistrictMenu(client, args) 
{
	District_MainMenu(client);
}


public Action:District_MainMenu(client)
{
	new Handle:menu = CreateMenu(DistrictMenu_Handle);

	decl String:szMsg[128];
	
	Format(szMsg, sizeof( szMsg ), "Choose your district!");
	SetMenuTitle(menu, szMsg);

	decl String:szItems1[128];
	Format(szItems1, sizeof( szItems1 ), "District 1" );

	decl String:szItems2[128];
	Format(szItems2, sizeof( szItems2 ), "District 2" );

	decl String:szItems3[128];
	Format(szItems3, sizeof( szItems3 ), "District 3" );

	decl String:szItems4[128];
	Format(szItems4, sizeof( szItems4 ), "District 4" );

	decl String:szItems5[128];
	Format(szItems5, sizeof( szItems5 ), "District 5" );
	
	decl String:szItems6[128];
	Format(szItems6, sizeof( szItems6 ), "District 6" );
	
	decl String:szItems7[128];
	Format(szItems7, sizeof( szItems7 ), "District 7" );
	
	decl String:szItems8[128];
	Format(szItems8, sizeof( szItems8 ), "District 8" );
	
	decl String:szItems9[128];
	Format(szItems9, sizeof( szItems9 ), "District 9" );
	
	decl String:szItems10[128];
	Format(szItems10, sizeof( szItems10 ), "District 10" );
	
	decl String:szItems11[128];
	Format(szItems11, sizeof( szItems11 ), "District 11" );

	decl String:szItems12[128];
	Format(szItems12, sizeof( szItems12 ), "District 12" );

	AddMenuItem(menu, "class_id", szItems1);
	AddMenuItem(menu, "class_id", szItems2);
	AddMenuItem(menu, "class_id", szItems3);
	AddMenuItem(menu, "class_id", szItems4);
	AddMenuItem(menu, "class_id", szItems5);
	AddMenuItem(menu, "class_id", szItems6);
	AddMenuItem(menu, "class_id", szItems7);
	AddMenuItem(menu, "class_id", szItems8);
	AddMenuItem(menu, "class_id", szItems9);
	AddMenuItem(menu, "class_id", szItems10);
	AddMenuItem(menu, "class_id", szItems11);
	AddMenuItem(menu, "class_id", szItems12);
	
	DisplayMenu(menu, client, 120 );	
}

public DistrictMenu_Handle(Handle:menu, MenuAction:action, client, item)
{
	if( action == MenuAction_Select )
	{
		district[client] = item+1;
		PrintToChat(client, "You have chosen %s", district_list[district[client]])
	}
	else if (action == MenuAction_End)	
	{
		CloseHandle(menu);	
	}
}

public EventHook_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(1.0, DelaySetDistrictTag)
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (district[client] != NONE)
	{
		PrintToChat(client, "You are  %s", district_list[district[client]])
	}

	if (district[client] == DISTRICTONE)
	{
		SetEntityHealth(client, 150)	
	}
}

public SetDistrictTag()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if( district[i] != NONE)
			{
				new String:ClanTag[32];
				Format(ClanTag, sizeof(ClanTag), "[%s]", district_list[district[i]])
				CS_SetClientClanTag(i, ClanTag)
			}
		}
	}
}

public Action:DelaySetDistrictTag(Handle:timer, any:client)
{
	SetDistrictTag();
}