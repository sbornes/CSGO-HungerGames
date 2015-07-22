#include <sourcemod>
#include <cstrike>
#include <smlib>
#include <sdkhooks>
#include <emitsoundany>

#include <hg_core>

new HungerPercentage[MAXPLAYERS+1];
new HydrationPercentage[MAXPLAYERS+1];
new StaminaPercentage[MAXPLAYERS+1]
new Handle:HungerTimer[MAXPLAYERS+1] = INVALID_HANDLE;
new Handle:HydrationTimer[MAXPLAYERS+1] = INVALID_HANDLE;
new bool:OnOffNotifications[MAXPLAYERS+1] = true;
new bool:boolInWater[MAXPLAYERS+1] = false;
new Float:NextHydrationTime[MAXPLAYERS+1];
new Float:NextHydrationTimeSound[MAXPLAYERS+1];
new Float:NextDamageTime[MAXPLAYERS+1];
new Float:NextSprintTime[MAXPLAYERS+1];
new Float:NextStaminaTime[MAXPLAYERS+1]
new Float:g_DrugAngles[20] = {0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -25.0, -20.0, -15.0, -10.0, -5.0};

new OriginOffset;

new String:g_HealthKit_Model[] = { "models/items/healthkit.mdl" }

#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) )

public OnPluginStart()
{
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("round_end", Event_OnRoundEnd);
	RegConsoleCmd("sm_notif", ToggleNotifications);

	OriginOffset = FindSendPropOffs("CBaseEntity", "m_vecOrigin");
	if(OriginOffset == -1)
		SetFailState("Error: Failed to find the origin offset, aborting");

}

public OnMapStart()
{
	//AddFileToDownloadsTable("models/HealthKit.mdl")
	AddFileToDownloadsTable("models/items/healthkit.dx80.vtx")
	AddFileToDownloadsTable("models/items/healthkit.dx90.vtx")
	AddFileToDownloadsTable("models/items/healthkit.mdl")
	AddFileToDownloadsTable("models/items/healthkit.phy")
	AddFileToDownloadsTable("models/items/healthkit.sw.vtx")
	AddFileToDownloadsTable("models/items/healthkit.vvd")
	AddFileToDownloadsTable("materials/models/items/healthkit01.vmt")
	AddFileToDownloadsTable("materials/models/items/healthkit01.vtf")
	AddFileToDownloadsTable("materials/models/items/healthkit01_mask.vtf")
	PrecacheModel(g_HealthKit_Model, true)

	AddFileToDownloadsTable("sound/hungergames/drinking.mp3");
	PrecacheSoundAny("hungergames/drinking.mp3");  
	AddFileToDownloadsTable("sound/hungergames/eating.mp3");
	PrecacheSoundAny("hungergames/eating.mp3");  
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_Touch, TouchPostCallback);
}

public HG_OnGameStart()
{
    for( new i = 1; i <= MaxClients; i++)
    {
        if( IsValidClient(i))
        {
			CreateTimer(0.1, SetStats, i);

			CreateTimer(1.0, HintText, i, TIMER_REPEAT)

			CreateTimer(1.0, Delay, i);        	
        }
    }
}

public TouchPostCallback(entity, other)
{
    new String:entClassName[33];
    GetEntityClassname(other, entClassName, sizeof(entClassName))
    if( StrEqual(entClassName, "hg_heatlhkit", false) )
    {    
        if( IsValidClient(entity) && !IsFakeClient(entity) )
        {
        	if( HungerPercentage[entity] < 50 )
        		HungerPercentage[entity] += 50;
        	else
        		HungerPercentage[entity] += 100;

        	new Float:soundOrigin[3];
        	GetEntityOrigin(entity, soundOrigin)

        	EmitAmbientSoundAny("hungergames/eating.mp3", soundOrigin, entity );

        	RemoveEdict(other);

        }
    }
}

public Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	NextHydrationTime[client] = 0.0;
	NextSprintTime[client] = 0.0;
	NextDamageTime[client] = 0.0;
	NextStaminaTime[client] = 0.0;
	NextHydrationTimeSound[client] = 0.0;

	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);

	resetTimer(client);
}

public Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	resetTimer(client)
}
public OnEntityDestroyed(entity)
{
	if (IsValidEntity(entity))
	{
		new String: classname[32];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "chicken"))
		{
			new Float:pOrigin[3];
			Entity_GetAbsOrigin(entity, pOrigin)
			//GetEntityOrigin(entity, pOrigin);
			new healthkit = CreateEntityByName("prop_physics_override")
			SetEntityModel(healthkit,g_HealthKit_Model)
			if (DispatchSpawn(healthkit))
			{
				Entity_SetClassName(healthkit, "hg_heatlhkit")
				SetEntProp(healthkit, Prop_Send, "m_usSolidFlags",  152)
				SetEntProp(healthkit, Prop_Send, "m_CollisionGroup", 11)
			}
			TeleportEntity(healthkit, pOrigin, NULL_VECTOR, NULL_VECTOR)
			
		}
	}
}

public Action:SetStats(Handle:timer, any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
	{
		HungerPercentage[client] = 100;
		HydrationPercentage[client] = 100;
		StaminaPercentage[client] = 100;
	}
}

public Action:Delay(Handle:timer, any:client)
{
	if( HungerTimer[client] == INVALID_HANDLE )
		HungerTimer[client] = CreateTimer(3.0, HungerTick, client, TIMER_REPEAT)
	if( HydrationTimer[client] == INVALID_HANDLE )
		HydrationTimer[client] = CreateTimer(2.5, HydrationTick, client, TIMER_REPEAT)
}

public OnGameFrame()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (HungerPercentage[i] == 0 && HG_GameStarted())
		{
			actionDamage(i)
		}

		if (IsValidClient(i) && IsPlayerAlive(i) && HG_GameStarted())
		{
			if(( GetEntProp(i, Prop_Send, "m_nWaterLevel") > 1 ))
			{
				if( GetGameTime() >= NextHydrationTime[i] && HydrationPercentage[i] != 100 )
	 			{
	 				boolInWater[i] = true;
	 				HydrationPercentage[i]++;
	 	 			NextHydrationTime[i] = GetGameTime() + 0.1;

	 	 			new Float:angs[3];
					GetClientEyeAngles(i, angs);
					if( angs[2] != 0.0)
					{
						angs[2] = 0.0
						TeleportEntity(i, NULL_VECTOR, angs, NULL_VECTOR)
					}

					if( GetGameTime() >= NextHydrationTimeSound[i] )
					{
			        	new Float:soundOrigin[3];
			        	GetEntityOrigin(i, soundOrigin)

			        	EmitAmbientSoundAny("hungergames/drinking.mp3", soundOrigin, i );

			        	NextHydrationTimeSound[i] = GetGameTime() + 3.0;
			        }
	 			}
	 		}
	 		else
	 		{
	 			if( boolInWater[i] )
	 				boolInWater[i] = false;
	 		}
	 	}

	 	if (StaminaPercentage[i] != 100 && HG_GameStarted())
	 	{
	 		if (IsValidClient(i) && IsPlayerAlive(i))
	 		{
	 			if (GetGameTime() >= NextStaminaTime[i])
	 			{
	 				StaminaPercentage[i]++;
	 				NextStaminaTime[i] = GetGameTime() + 0.5;
	 			}
	 		}
	 	}
	}	
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{

	if (StaminaPercentage[client] >= 10 && buttons & IN_JUMP && GetEntityFlags(client) & FL_ONGROUND)
	{
		if (IsPlayerAlive(client))
		{
			StaminaPercentage[client]-=10;
		}
	}
	else 
	{
		if (IsPlayerAlive(client))
		{
			buttons &= ~IN_JUMP;
		}		
	}

	if (buttons & IN_USE && StaminaPercentage[client] > 0)
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.25);
		if (GetGameTime() >= NextSprintTime[client] && IsValidClient(client) && IsPlayerAlive(client))
		{
			StaminaPercentage[client]--;
			NextSprintTime[client] = GetGameTime() + 0.05;
		}
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
	}
}

actionDamage(client)
{
	if (GetGameTime() >= NextDamageTime[client] && IsValidClient(client) && IsPlayerAlive(client))
	{
		if (Entity_GetHealth(client) > 0)			{
			new amount = 1;
			Entity_SetHealth(client, Entity_GetHealth(client) - amount)
		}
		NextDamageTime[client] = GetGameTime() + 0.5;
	}
}		


resetTimer(client)
{
	if( HydrationTimer[client] != INVALID_HANDLE)
	{
		KillTimer(HydrationTimer[client])
		HydrationTimer[client] = INVALID_HANDLE;
	}
	
	if( HungerTimer[client] != INVALID_HANDLE)
	{
		KillTimer(HungerTimer[client])
		HungerTimer[client] = INVALID_HANDLE;
	}
}

public Action:HintText(Handle:timer, any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && HG_GameStarted())
	{
		PrintHintText(client, " <font color='#ff0000'>Hunger</font>: %d%% \n <font color='#0000ff'>Hydration</font>: %d%% \n <font color='#ffff00'>Stamina</font>: %d%%", HungerPercentage[client], HydrationPercentage[client], StaminaPercentage[client]);	
	}
}

public Action:HungerTick(Handle:timer, any:client)
{
	if (HungerPercentage[client] != 0)
	{
		HungerPercentage[client]--;
	}

	if (HungerPercentage[client] == 25 && OnOffNotifications[client] == true)
	{
		PrintToChat(client, "Your hunger bar has reached 25%")
		PrintToChat(client, "Kill chickens and pick up food to restore some of your hunger bar")
		PrintToChat(client, "Remember, once your hunger bar reaches 0%, you will slowly die of starvation")
	}
	else if (HungerPercentage[client] == 0 && OnOffNotifications[client] == true)
	{
		PrintToChat(client, "Your hunger bar has reached 0%")
		PrintToChat(client, "You will slowly die of starvation. Kill chickens and pick up food to restore some of your hunger bar")
	}
}

public Action:ToggleNotifications(client, args) 
{
	if (OnOffNotifications[client] == true)
	{
		OnOffNotifications[client] = false;
		PrintToChat(client, "You have disabled notifications. Say !notif to enable them again.")
	}
	else if (OnOffNotifications[client] == false)
	{
		OnOffNotifications[client] = true;
		PrintToChat(client, "You have enabled notifications. Say !notif to disable them.")
	}
}

public Action:HydrationTick(Handle:timer, any:client)
{
	if (HydrationPercentage[client] != 0 && !boolInWater[client])
	{
		HydrationPercentage[client]--;
	}
	else if (IsValidClient(client) && IsPlayerAlive(client) && HydrationPercentage[client] == 0 )
	{
		new Float:angs[3];
		GetClientEyeAngles(client, angs);
	
		angs[2] = g_DrugAngles[GetRandomInt(0,100) % 20];
	
		TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);
	}

	if (HydrationPercentage[client] == 25 && OnOffNotifications[client] == true)
	{
		PrintToChat(client, "Your hydration bar has reached 25%")
		PrintToChat(client, "Drink water to restore some of your hydration bar")
		PrintToChat(client, "Remember, once your hydration bar reaches 0%, you will start to become dizzy")
	}
	else if (HydrationPercentage[client] == 0 && OnOffNotifications[client] == true)
	{
		PrintToChat(client, "Your hydration bar has reached 0%")
		PrintToChat(client, "You are now dizzy due to hydration. Drink some water to not be dizzy anymore")
	}
}

public GetEntityOrigin(entity, Float:output[3])
{
	GetEntDataVector(entity, OriginOffset, output);
}