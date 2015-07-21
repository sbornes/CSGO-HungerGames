#include <sourcemod>
#include <smlib>
#include <sdkhooks>
#include <sdktools>
#include <emitsoundany>

#include <hg_core>
#include <hg_zombies>

#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1) )

#define rewards_MAX 11
#define reward_Pistol_MAX 9
#define reward_Rifle_MAX 4
#define reward_Shotgun_MAX 4
#define reward_SMG_MAX 5
#define reward_Sniper_MAX 4

new OriginOffset;
new g_iVelocity = -1;

new Parachute_Ent[2048];
new bool:Parachute_Ent_InUse[2048];
new Handle:AirDropTimer = INVALID_HANDLE;
new String:KVPath[PLATFORM_MAX_PATH];
new PosNumber = 0;
new AirDropLastLocation;

enum // REWARDS 
{
    reward_HealthKit,
    reward_Armour,
    reward_Pistol,
    reward_Rifle,
    reward_Shotguns,
    reward_SMGs,
    reward_Snipers,
    reward_Taser,
    reward_Flashbang,
    reward_Smokegrenade,
    reward_Hegrenade
}

new const String:reward_Secondary_List[][] = 
{
    "weapon_usp_silencer",
    "weapon_hkp2000",
    "weapon_p250",
    "weapon_fiveseven",
    "weapon_elite",
    "weapon_glock",
    "weapon_deagle",
    "weapon_tec9",
    "weapon_cz75a"
}

new const String:reward_Primary_List[][] = 
{
    "weapon_m4a1",
    "weapon_ak47",
    "weapon_galilar",
    "weapon_famas"
}

new const String:reward_Shotgun_List[][] = 
{
    "weapon_mag7",
    "weapon_nova",
    "weapon_sawedoff",
    "weapon_xm1014"
}

new const String:reward_SMG_List[][] = 
{
    "weapon_p90",
    "weapon_mp7",
    "weapon_mp9",
    "weapon_mac10",
    "weapon_ump45"
}

new const String:reward_Sniper_List[][] = 
{
    "weapon_ssg08",
    "weapon_awp",
    "weapon_aug",
    "weapon_ssg08"
}

public OnPluginStart()
{
    HookEvent("round_end", Event_OnRoundEnd);
    // Loot Crate
    RegAdminCmd("hg_lootcrate", CallBack_LootCrate, ADMFLAG_KICK, "Spawns a Loot Crate");
    RegAdminCmd("hg_spawn", CallBack_CreateSpawn, ADMFLAG_KICK, "Creates Loot Crate Spawn");
    // Other
    OriginOffset = FindSendPropOffs("CBaseEntity", "m_vecOrigin");
    if(OriginOffset == -1)
        SetFailState("Error: Failed to find the origin offset, aborting");

    g_iVelocity = FindSendPropOffs("CBasePlayer", "m_vecVelocity[0]");

    CreateDirectory("addons/sourcemod/configs/HungerGames/Locations", 3);
}

public OnMapStart()
{
    PrecacheModel("models/props/de_nuke/crate_small.mdl", true);
    // Parachute
    PrecacheModel("models/parachute/parachute_carbon.mdl",true);
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.mdl" );
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.dx80.vtx" );
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.dx90.vtx" );
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.sw.vtx" );
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.vvd" );
    AddFileToDownloadsTable( "models/parachute/parachute_carbon.xbox.vtx" );
    AddFileToDownloadsTable( "materials/models/parachute/parachute_carbon.vmt" );
    AddFileToDownloadsTable( "materials/models/parachute/parachute_carbon.vtf" );
    AddFileToDownloadsTable( "materials/models/parachute/pack_carbon.vtf" );
    AddFileToDownloadsTable( "materials/models/parachute/pack_carbon.vmt" );

    PosNumber = 0;
    new String:CurrentMap[32];
    GetCurrentMap(CurrentMap, sizeof(CurrentMap))
    BuildPath(Path_SM, KVPath, sizeof(KVPath), "configs/HungerGames/Locations/%s.txt", CurrentMap);
    LoadLocations();
}

public HG_OnGameStart()
{
    if( AirDropTimer == INVALID_HANDLE )
        AirDropTimer = CreateTimer(5.0, AirDrop, _, TIMER_REPEAT);
}

public Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    if( AirDropTimer != INVALID_HANDLE )
    {
        KillTimer(AirDropTimer);
        AirDropTimer = INVALID_HANDLE;
    }
}

public Action:AirDrop(Handle:timer)
{
    if (FileExists(KVPath))
    {   
        new randomlocation = GetRandomInt(1, PosNumber-1);
        while( randomlocation == AirDropLastLocation)
            randomlocation = GetRandomInt(1, PosNumber-1);

        AirDropLastLocation = randomlocation;

        new Handle:DB = CreateKeyValues("Locations");
        FileToKeyValues(DB, KVPath);

        new String:PosString[32];
        IntToString(randomlocation, PosString, sizeof(PosString))
        if( KvJumpToKey(DB, PosString, false) )
        { 
            new Float:Origin[3];
            Origin[0] = KvGetFloat(DB, "x");
            Origin[1] = KvGetFloat(DB, "y");
            Origin[2] = KvGetFloat(DB, "z");
            SpawnCrate( Origin, true);
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_Touch, TouchPostCallback);
}

public OnGameFrame()
{
    //decl String:szClass[65]; 
    new i = -1;
    while((i = FindEntityByClassname(i, "hg_lootcrate")) != INVALID_ENT_REFERENCE)
    {
        if(IsValidEntity(i)) 
        { 
            decl Float:vecOrigin[3], Float:vecPos[3], Float:vecAng[3] = {90.0, 0.0, 0.0}; 
            GetEntityOrigin(i, vecOrigin)
            //GetClientAbsOrigin(i, vecOrigin); 
            new Handle:trace = TR_TraceRayFilterEx(vecOrigin, vecAng, MASK_ALL, RayType_Infinite, TraceRayTryToHit, i);
            TR_GetEndPosition(vecPos, trace); 
            if( /*GetVectorDistance(vecOrigin, vecPos)*/ vecOrigin[2] - vecPos[2] > 100.0 ) 
            { 
                StartPara(i,false);
                TeleportParachute(i);
            }
            else
            {
                EndPara(i);
            } 
            
            CloseHandle(trace);

        }   
    }
}
/* [ Touch Event ] */
public TouchPostCallback(entity, other)
{
    if( isLootCrate(other) )
    {    
        if( IsValidClient(entity) && !IsFakeClient(entity) )
        {
            giveRandomItem(entity);
            EndPara(other);
            AcceptEntityInput(other, "break");
            //RemoveEdict(other);
            //Entity_Hurt(other, 1, entity, DMG_GENERIC);

        }
    }
}

bool:isLootCrate(ent)
{
    new String:entClassName[33];
    GetEntityClassname(ent, entClassName, sizeof(entClassName))
    if( StrEqual(entClassName, "hg_lootcrate", false) )
        return true;

    return false;
}

/* [ Loot Crate ] */
public giveRandomItem(client)
{
	if( IsValidClient(client) )
    {
    	new item = GetRandomInt(0, rewards_MAX);
    	switch(item)
    	{
    		case reward_HealthKit: 
    		{
                new Heal = GetRandomInt(0, 50);
                if( GetClientHealth(client) < Heal )
                    SetEntityHealth(client, GetClientHealth(client) + Heal);  
                else
                    SetEntityHealth(client, 100); 

                //PrintToChat(client, "DEBUG: found hp");  
    		} 
    		case reward_Armour:
    		{
                new Armour = GetRandomInt(0, 50);
                if( GetClientArmor(client) < Armour )
                    Client_SetArmor(client, GetClientArmor(client) + Armour);
                else
                    Client_SetArmor(client, 100); 
                //PrintToChat(client, "DEBUG: found armour"); 
    		}
    		case reward_Pistol:
    		{
                new randnum = GetRandomInt(0, reward_Pistol_MAX);

                new Handle:pack; 
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, reward_Secondary_List[randnum]);
                //PrintToChat(client, "DEBUG: found %s", reward_Secondary_List[randnum]); 
            }
            case reward_Rifle:
            {
                new randnum = GetRandomInt(0, reward_Rifle_MAX)

                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, reward_Primary_List[randnum]);
                //PrintToChat(client, "DEBUG: found %s", reward_Primary_List[randnum]);  		
    		}
            case reward_Shotguns:
            {
                new randnum = GetRandomInt(0, reward_Shotgun_MAX)

                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, reward_Shotgun_List[randnum]);
                //PrintToChat(client, "DEBUG: found %s", reward_Shotgun_List[randnum]);   
            }
            case reward_SMGs:
            {
                new randnum = GetRandomInt(0, reward_SMG_MAX)

                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, reward_SMG_List[randnum]);   
                //PrintToChat(client, "DEBUG: found %s", reward_SMG_List[randnum]);      
            }
            case reward_Snipers:
            {
                new randnum = GetRandomInt(0, reward_Sniper_MAX)

                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, reward_Sniper_List[randnum]);  
                //PrintToChat(client, "DEBUG: found %s", reward_Sniper_List[randnum]);          
            }
            case reward_Taser:
            {
                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, "weapon_taser");   
                //PrintToChat(client, "DEBUG: found weapon_taser");   
            }
            case reward_Flashbang:
            {
                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, "weapon_flashbang");   
                //PrintToChat(client, "DEBUG: found weapon_flashbang"); 
            }
            case reward_Smokegrenade:
            {
                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, "weapon_smokegrenade"); 
                //PrintToChat(client, "DEBUG: found weapon_smokegrenade");     
            }
            case reward_Hegrenade:
            {
                new Handle:pack;
                CreateDataTimer(0.1, reward_GiveWep, pack);
                WritePackCell(pack, client);
                WritePackString(pack, "weapon_hegrenade");   
                //PrintToChat(client, "DEBUG: found weapon_hegrenade");   
            }
        } 
    }
}

public Action:reward_GiveWep(Handle:timer, Handle:pack)
{
    new client;
    decl String:Wepp[1024];

    ResetPack(pack);
    client = ReadPackCell(pack)
    ReadPackString(pack, Wepp, sizeof(Wepp));

    if( (GetPlayerWeaponSlot(client, 2)) == -1)
        GivePlayerItem(client, "weapon_knife");

    PrintToChat(client, "DEBUG: reward_GiveWep %s", Wepp)
    GivePlayerItem(client, Wepp);
}

public OnEntityDestroyed(entity)
{
    if (IsValidEntity(entity))
    {
        new String: classname[32];
        GetEntityClassname(entity, classname, sizeof(classname));
        if (StrEqual(classname, "hg_lootcrate"))
        {
            EndPara(entity)
        }
    } 
}

public Action:CallBack_CreateSpawn(client, args)
{
    new Float:Origin[3];
    GetEntityOrigin(client, Origin)

    new Handle:DB = CreateKeyValues("Locations");
    FileToKeyValues(DB, KVPath);

    new String:strNumber[32];
    IntToString(PosNumber, strNumber, sizeof(strNumber))

    if( KvJumpToKey(DB, strNumber, true))
    {
        KvSetFloat(DB, "x", Origin[0])
        KvSetFloat(DB, "y", Origin[1])
        KvSetFloat(DB, "z", Origin[2])
    }

    KvRewind(DB);
    KeyValuesToFile(DB, KVPath);

    CloseHandle(DB);
    PosNumber++;

    PrintToChat(client, "LootCrates: Position #%d saved %.0f %.0f %.0f", PosNumber, Origin[0], Origin[1], Origin[2]);
}

LoadLocations()
{
    if (FileExists(KVPath))
    {   
        new Handle:DB = CreateKeyValues("Locations");
        FileToKeyValues(DB, KVPath);

        new String:StringNumber[32];
        IntToString(PosNumber, StringNumber, sizeof(StringNumber))
        while( KvJumpToKey(DB, StringNumber, false) )
        {
            PosNumber++
            IntToString(PosNumber, StringNumber, sizeof(StringNumber))
            KvRewind(DB);
        }
        CloseHandle(DB);
        PrintToServer("LootCrates: %d Locations Loaded", PosNumber)
    }
}

public Action:CallBack_LootCrate(client, args)
{
    new Float:fOrigin[3];
    GetEntityOrigin(client, fOrigin);   
    SpawnCrate( fOrigin, true );

    PrintToChatAll(" Admin \x04%N \x01has called in a loot drop at his location!", client);

    return Plugin_Handled;
}

/* Spawn Loot Crate */
SpawnCrate(Float:fOrigin[3] = { 0.0, 0.0, 0.0 }, bool:Falling)
{
    new iEntity = CreateEntityByName("prop_physics_override"); 

    DispatchKeyValue(iEntity, "classname", "hg_lootcrate");
    DispatchKeyValue(iEntity, "targetname", "prop");
    Entity_SetClassName(iEntity, "hg_lootcrate");
    DispatchKeyValue(iEntity, "model", "models/props/de_nuke/crate_small.mdl");
    DispatchKeyValue(iEntity, "solid", "6");
    if ( DispatchSpawn(iEntity) ) 
    {
        //SetEntProp(iEntity, Prop_Send, "m_fEffects", enteffects);  
        if( Falling ) 
        {
            decl Float:vecOrigin[3], Float:vecPos[3], Float:vecAng[3] = {-90.0, 0.0, 0.0}; 
            GetEntityOrigin(iEntity, vecOrigin)
            //GetClientAbsOrigin(i, vecOrigin); 
            new Handle:trace = TR_TraceRayFilterEx(vecOrigin, vecAng, MASK_ALL, RayType_Infinite, TraceRayTryToHit, iEntity);
            TR_GetEndPosition(vecPos, trace); 

            fOrigin[2] = vecPos[2]-100; 
            CloseHandle(trace);
            //fOrigin[2] += 700;
            StartPara(iEntity, true);
        } 

        TeleportEntity(iEntity, fOrigin, NULL_VECTOR, NULL_VECTOR); 
        SetEntProp(iEntity, Prop_Data, "m_takedamage", DAMAGE_YES, 1);
        SetEntProp(iEntity, Prop_Data, "m_iHealth", 50);
        SetEntProp(iEntity, Prop_Send, "m_usSolidFlags",  152);
        SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 8);
        AcceptEntityInput(iEntity, "EnableMotion");
        return iEntity;
    }   

    return -1;
}

/* [ Parachute ] - taken from SM Parachute */
public StartPara(client,bool:open)
{
    decl Float:velocity[3];
    decl Float:fallspeed;
    new bool:isfallspeed;
    if (g_iVelocity == -1) return;
    fallspeed = 100*(-1.0);
    //GetEntDataVector(client, g_iVelocity, velocity);
    velocity[0] = 0.0;
    velocity[1] = 0.0;
    velocity[2] = -100.0;

    if(velocity[2] >= fallspeed)
    {
        isfallspeed = true;
    }
    if(velocity[2] < 0.0) 
    {
        if(isfallspeed)
        {
            velocity[2] = fallspeed;
        }
        else
        {
			velocity[2] = velocity[2] + 50;
        }
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
        SetEntDataVector(client, g_iVelocity, velocity);
        SetEntityGravity(client,0.1);
        if(open) OpenParachute(client);
    }
}

public EndPara(ent)
{
    if(IsValidEdict(ent) && IsValidEntity(ent)) 
    {
        //SetEntityGravity(ent, 1.0);
        CloseParachute(ent);
    }
}

OpenParachute(Ent)
{
    Parachute_Ent[Ent] = CreateEntityByName("prop_dynamic_override");
    DispatchKeyValue(Parachute_Ent[Ent],"model", "models/parachute/parachute_carbon.mdl");
    SetEntityMoveType(Parachute_Ent[Ent], MOVETYPE_NOCLIP);
    DispatchSpawn(Parachute_Ent[Ent]);    

    Parachute_Ent_InUse[Ent] = true;
    TeleportParachute(Ent);
}

CloseParachute(ent)
{
    if(IsValidEntity(Parachute_Ent[ent]))
    {
        Parachute_Ent_InUse[ent] = false;
        RemoveEdict(Parachute_Ent[ent]);
    }
}

public TeleportParachute(Ent)
{
    if(IsValidEntity(Parachute_Ent[Ent]))
    {
        decl Float:Client_Origin[3];
        //decl Float:Client_Angles[3];
        //decl Float:Parachute_Angles[3] = { 0.0, 0.0, 0.0 };
        GetEntityOrigin(Ent, Client_Origin)
        //GetClientAbsOrigin(Ent,Client_Origin);
        //GetClientAbsAngles(Ent,Client_Angles);
        //Parachute_Angles[1] = Client_Angles[1];
        TeleportEntity(Parachute_Ent[Ent], Client_Origin, NULL_VECTOR/*Parachute_Angles*/, NULL_VECTOR);
    }
}

/* Stocks */
public GetEntityOrigin(entity, Float:output[3])
{
    GetEntDataVector(entity, OriginOffset, output);
}

public bool:TraceRayTryToHit(entity, mask, any:data)
{
    // Check if the beam hit a player and tell it to keep tracing if it did
    if(entity == data)
        return false;
    return true;
}