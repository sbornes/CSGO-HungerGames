#include <sourcemod>
#include <cstrike>
#include <smlib>
#include <sdkhooks>
#include <emitsoundany>

#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) )

new g_beamsprite, g_halosprite;
new OriginOffset;

public OnPluginStart()
{
	HookEvent("player_death", Event_OnPlayerDeath)
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post)
	OriginOffset = FindSendPropOffs("CBaseEntity", "m_vecOrigin");
	if(OriginOffset == -1)
		SetFailState("Error: Failed to find the origin offset, aborting");
}

public OnMapStart()
{
	g_beamsprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_halosprite = PrecacheModel("materials/sprites/halo.vmt");

	AddFileToDownloadsTable("sound/hungergames/hg_cannon2.mp3");
	PrecacheSoundAny("hungergames/hg_cannon2.mp3", true);
}

public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	EmitSoundToAllAny("hungergames/hg_cannon2.mp3")
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!IsValidClient(attacker) || !IsValidClient(victim))
		return;


	if (attacker == 0)
	{
		PrintToChatAll("%N was killed by natural causes", victim)
	}
	else if (IsValidClient(attacker) && IsValidClient(victim))
	{
		PrintToChatAll("%N has been killed by %N", victim, attacker)
	}

	if (playersalive() > 2)
	{
		PrintToChatAll("%d players remain", playersalive())			
	}
	else if(playersalive() == 2)
	{
		PrintToChatAll("Only 2 players remain!")
		CreateTimer(1.0, PlayerBeacon, _, TIMER_REPEAT)
	}
	else if(playersalive() == 1)
	{
		PrintToChatAll("%N has been crowned the victor of the Hunger Games!", playername())
		PrintToChatAll("New Hunger Games starting in 5 seconds!")
		ServerCommand("sm_cvar mp_restartgame 5");
	}	
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if (playersalive() > 2)
	{
		PrintToChatAll("%d players remain", playersalive())
	}
	else if (playersalive() == 2)
	{
		PrintToChatAll("Only 2 players remain!", playersalive())
		CreateTimer(1.0, PlayerBeacon, _, TIMER_REPEAT)
	}
}

public Action:PlayerBeacon(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			new Float:pOrigin[3];
			GetEntityOrigin(i, pOrigin);
			TE_SetupBeamRingPoint(pOrigin, 10.0, 1000.0, g_beamsprite, g_halosprite, 1, 1, 0.0, 1.0, 1.0, {255, 255, 255, 255}, 1, 1)
	  		TE_SendToAll();				
  		}
	}
}

stock playersalive()
{
	new playersalivevar;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			playersalivevar++
		}
	}
	return playersalivevar
}

stock playername()
{
	new playernamevar;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			playernamevar = i
		}
	}
	return playernamevar
}
public GetEntityOrigin(entity, Float:output[3])
{
	GetEntDataVector(entity, OriginOffset, output);
}
