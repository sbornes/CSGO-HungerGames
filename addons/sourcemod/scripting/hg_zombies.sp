#include <sourcemod>
#include <cstrike>
#include <sdktools> 
#include <sdkhooks>
#include <smlib>

#define TEAM_HUMAN 1
#define TEAM_ZOMBIE 2
new HG_PlayerClass[MAXPLAYERS+1];

public OnPluginStart()
{
    HookEvent("player_spawn", Player_Spawn);
    HookEvent("round_start", Round_Start);
    HookEvent("player_death", Player_Death);

    RegAdminCmd("debug", CallBack_debug, ADMFLAG_KICK, "   ");
} 


public Action:CallBack_debug(client, args)
{
    if( HG_PlayerClass[client] == TEAM_HUMAN )
        PrintToChatAll(" client: Human");
    else
        PrintToChatAll(" client: Zombie");

    return Plugin_Handled;
}


public OnMapStart()
{
    PrecacheModel("models/player/zombie.mdl", true);
}


public Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGame(i) && IsPlayerAlive(i) )
        {
            HG_PlayerClass[i] = TEAM_HUMAN;
        }
    }
    //CreateTimer(30.0, ReviveZombies);
}


public Player_Death(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	//new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if( HG_PlayerClass[victim] == TEAM_HUMAN )
		CreateTimer(0.5, Make_Zombie, victim);
}

public Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if( HG_PlayerClass[client] != TEAM_ZOMBIE ) {
        HG_PlayerClass[client] = TEAM_HUMAN;
        CS_SwitchTeam(client, CS_TEAM_CT);
    }
    else
    {
        Entity_SetModel(client, "models/player/zombie.mdl");
    }  
}

public Action:Make_Zombie(Handle:timer, any:client)
{
    HG_PlayerClass[client] = TEAM_ZOMBIE;
    CS_SwitchTeam(client, CS_TEAM_T);
    if( !IsPlayerAlive(client) )
        CS_RespawnPlayer(client);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{   
    CreateNative("HG_IsZombie", Native_HG_IsZombie);
    CreateNative("HG_IsHuman", Native_HG_IsHuman);
    CreateNative("HG_ChangeToHuman", Native_HG_ChangeToHuman);
    CreateNative("HG_ChangeToZombie", Native_HG_ChangeToZombie);
    CreateNative("HG_GetClass", Native_HG_GetClass);
    return APLRes_Success;
}

public Native_HG_IsZombie(Handle:plugin, numParams)
{
    if( HG_PlayerClass[GetNativeCell(1)] == TEAM_ZOMBIE )
        return true;
    return false;
}

public Native_HG_IsHuman(Handle:plugin, numParams)
{
    if( HG_PlayerClass[GetNativeCell(1)] == TEAM_HUMAN )
        return true;
    return false;
}

public Native_HG_ChangeToHuman(Handle:plugin, numParams)
{
    HG_PlayerClass[GetNativeCell(1)] = TEAM_HUMAN;
    ChangeClientTeam(GetNativeCell(1), CS_TEAM_CT);
}

public Native_HG_ChangeToZombie(Handle:plugin, numParams)
{
    HG_PlayerClass[GetNativeCell(1)] = TEAM_ZOMBIE;
    ChangeClientTeam(GetNativeCell(1), CS_TEAM_T);
    if( bool:GetNativeCell(2) )
    {
        CS_RespawnPlayer(GetNativeCell(1));
    } 
}

public Native_HG_GetClass(Handle:plugin, numParams)
{
    return HG_PlayerClass[GetNativeCell(1)];
}
