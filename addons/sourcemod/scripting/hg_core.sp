/* 
{ 

    [✓]   - Completed
    [~]   - Work In Progress
    []  - Not Started

 |__   __/ __ \  |  __ \ / __ \  | |    |_   _|/ ____|__   __|
    | | | |  | | | |  | | |  | | | |      | | | (___    | |   
    | | | |  | | | |  | | |  | | | |      | |  \___ \   | |   
    | | | |__| | | |__| | |__| | | |____ _| |_ ____) |  | |   
    |_|  \____/  |_____/ \____/  |______|_____|_____/   |_|   
                                          
    GAMEPLAY                  
    - Enable FFA                        [✓]
    - Disable Radar                     [✓] 
    - Disable HUD( HP and AR )          [✓]
    - Red Overlay for when hurt         []
    - Hunger System                     [~]
    - Bleed System ?                    []
    - Day / Night Cycle                 []
    - Days Counter                      []
    - Custom Weapons                    []
    - Loot Crates / Drops               [✓]
    - Chat in a Radius                  []
    - Disable Radio                     []
    - Zombies when dead to speed game?  []
    - Map Shrink as time goes on?       []
    - Last TWO Players Can Truce        []

    ITEMS / INVENTORY
    - Bandages to stop Bleed            []
    - Swords / Shields ?                []
    - Knife Throw ?                     []

    LOOT DROPS                          [~]
    - Guns with 1-x bullets             []
    - Ammo                              []
    - Health Kits                       []
    - Armour                            []
    - Tech Drops?                       []

    TECH DROPS?
    - ReEnable Radar                    []
    - Closest Enemy xx distance         []
    - Boots/Silent Footsteps            []

    SOUNDS
    - Cannon Death                      [✓]
    - Bleed Sound                       []
    - Sprint Sound                      []
    - Environment Sounds                []
        - Rain                          []
        - Snow                          []
        - Fire                          []
        - Lightning                     []
        - Tornado                       []
        - Normal                        []

    MODELS
    - Players                           []

    STATS
    - Save / Load                       []
    - Games Played                      []
    - Lone Survivor Wins                []
    - Truce Wins                        []  
    - Kills                             []
    - Deaths                            []
    - KDA Ratio                         [] 
    - Top 10                            []
    - /Rank                             []

    CHARACTER LEVEL SYSTEM
    - EXP on Kills                      []
    - EXP on Wins                       []
    - Increase Stamina 
        ( Sprint )                      []
    - Increase Endurance 
        ( Decrease Bleed Time )         []
    - Increase Strength 
        ( Jump Higher? )                []

    Incorporate 6 Senses ?              []

        1.  Sound - Larger Radius for hearing other players talk
        2.  Taste - Increase healing from food
        3.  Touch - Faster Looting
        4.  Sight - Decrease Fog ? If possible
        5.  Smell - ??

    WEATHER / EVENT SYSTEM
    - Rain                              []
    - Snow                              []
    - Fire                              []
    - Lightning                         []
    - Tornado                           []
    - Normal                            []

    ZOMBIE SYSTEM
    - Player Respawns as a zombie       []
    - Very Low HP, 1HIT ?               []
    - Very Low DMG                      []
    - Radar Enable                      []
    - Knife Skin Change                 []
    - Model Skin Change                 []

    Note: Idea is to increase the speed of late game and to keep players playing.

    TIPS CYCLE
    - Voicechat limited Distance        []
    - Map shrinking as time goes on     []
    - Turn into zombies to speed game   []
    - Minimum 2 players to Win          []
    - Form Teams to increase % win      []

    TEAM WINS
    - Limit Team Size   4?              []
    - Store Team Name                   []
    - Store Team Wins/Losts             []

    PERKS                               [✓]

}
 */         

#define HIDEHUD_HEALTH              1<<3
#define HIDEHUD_RADAR               1<<12

#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1) )

#include <sourcemod>
#include <cstrike>
#include <emitsoundany>

new Handle:hDisableRadar = INVALID_HANDLE;
new Handle:hDisableHPAR = INVALID_HANDLE;
new Handle:hRoundStart = INVALID_HANDLE;
new Handle:hg_roundstart = INVALID_HANDLE;
new Handle:hg_showpos = INVALID_HANDLE;
new Handle:hOnGameStart = INVALID_HANDLE;
new bool:HG_ShowPos[MAXPLAYERS+1];
new bool:HG_Started = false;
new timertick = 0;

#define HGMAXTIPS 6
new const String:gGamePlayTips[HGMAXTIPS][] = 
{
    "Crate drops occur once every 15seconds!",
    "Refill your hunger by killing chickens!",
    "Refill your hydration by finding water!",
    "Hold E (+use) key to sprint!",
    "Jumping requires a minimum of 10 stamina!",
    "say !pos to display your current co-ordinates!"
}

public OnPluginStart()
{
    HookEvent("player_spawn", Player_Spawn);
    HookEvent("round_start", Round_Start);
    HookEvent("round_end", Round_End);

    hDisableRadar = CreateConVar("hg_disableradar", "1", "Disable Radar?", _, true, _, true, 1.0);
    hDisableHPAR = CreateConVar("hg_disablehpar", "0", "Disable HP and AR HUD?", _, true, _, true, 1.0);

    hg_roundstart = CreateConVar("hg_roundstart", "15", "Freeze time");
    hg_showpos = CreateConVar("hg_showpos", "1", "cl_showpos");

    RegConsoleCmd("sm_pos", TogglePos);

    CreateTimer(30.0, GamePlayTips, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapStart()
{
    InitCvars();
    AddFileToDownloadsTable("sound/hungergames/roundstart.mp3");
    PrecacheSoundAny("hungergames/roundstart.mp3");   
}

InitCvars()
{
    SetCvar("mp_friendlyfire", "1");
    SetCvar("mp_startmoney", "0");
    SetCvar("mp_teammates_are_enemies", "1");
    SetCvar("mp_ct_default_secondary", "");
    SetCvar("mp_t_default_secondary", "");
    SetCvar("mp_warmuptime", "0");
    SetCvar("mp_roundtime", "10");
    SetCvar("mp_do_warmup_period", "0");
    SetCvar("mp_buytime", "0");
    new String:freezetime[32];
    IntToString(GetConVarInt(hg_roundstart), freezetime, sizeof(freezetime));
    SetCvar("mp_freezetime", freezetime); 
    SetCvar("mp_solid_teammates", "1"); 
}

public Round_Start(Handle:event, const String:name[], bool:dontBroadcast) 
{
    EmitSoundToAllAny( "hungergames/roundstart.mp3"); 

    if( hRoundStart != INVALID_HANDLE )
    {
        KillTimer(hRoundStart);
        hRoundStart = INVALID_HANDLE;    
    }

    if( hRoundStart == INVALID_HANDLE )
    {
        timertick = 0;
        hRoundStart = CreateTimer( 1.0, PreGame, _, TIMER_REPEAT );
    }
}

public Round_End(Handle:event, const String:name[], bool:dontBroadcast) 
{
    if( hRoundStart != INVALID_HANDLE )
    {
        KillTimer(hRoundStart);
        hRoundStart = INVALID_HANDLE;    
    }

    HG_Started = false;
}


public Action:PreGame(Handle:timer)
{
    timertick++;
    new String:SecColour[32];
    new timeleft = GetConVarInt(hg_roundstart) - timertick;
    if( timeleft >= 10 )
        Format(SecColour, sizeof(SecColour), "<font color='#00ff00'>%d</font>", timeleft);
    else if( timeleft >= 5 )
        Format(SecColour, sizeof(SecColour), "<font color='#ffff00'>%d</font>", timeleft);
    else if( timeleft >= 0 )
        Format(SecColour, sizeof(SecColour), "<font color='#ff0000'>%d</font>", timeleft); 
              
    PrintHintTextToAll("<font size='30'><b>ROUND STARTS IN \n              %s</b></font>", SecColour );

    if( timertick == GetConVarInt(hg_roundstart))
    {
        Call_StartForward(hOnGameStart);
        Call_Finish();
        KillTimer(hRoundStart);
        hRoundStart = INVALID_HANDLE;

        HG_Started = true;

        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    hOnGameStart = CreateGlobalForward("HG_OnGameStart", ET_Ignore, Param_Cell, Param_String);
    CreateNative("HG_GameStarted", Native_HG_GameStart);
    return APLRes_Success;
}

public Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    CreateTimer(0.0, RemoveHUD, client);
}  


public Action:RemoveHUD(Handle:timer, any:client) 
{
    if( GetConVarInt(hDisableRadar) )
        SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_RADAR);

    if( GetConVarInt(hDisableHPAR) )
        SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_HEALTH);

}

public Action:GamePlayTips(Handle:timer)
{
    new RandomTip = GetRandomInt(0, HGMAXTIPS-1);
    for( new i = 1; i <= MaxClients; i++ )
    {
        if( IsClientConnected(i) && IsClientInGame(i) )
        {
            PrintToChat(i, " \x04TIPS #%d/%d: \x01%s", RandomTip+1, HGMAXTIPS, gGamePlayTips[RandomTip]);
        }
    }
}

public Action:TogglePos(client, args) 
{
    if( GetConVarInt(hg_showpos) )
    {
        if (HG_ShowPos[client] == true)
        {
            HG_ShowPos[client] = false;
            ClientCommand(client, "cl_showpos 0");
            PrintToChat(client, "You have disabled positions. Say !pos to enable them again.")
        }
        else if (HG_ShowPos[client] == false)
        {
            HG_ShowPos[client] = true;
            ClientCommand(client, "cl_showpos 1");
            PrintToChat(client, "You have enabled positions. Say !pos to disable them.")
        }
    }
    else
    {
        PrintToChat(client, "Show Pos is currently disabled.")
    }
}

stock SetCvar(String:scvar[], String:svalue[])
{
    new Handle:cvar = FindConVar(scvar);
    SetConVarString(cvar, svalue, true);
}

public Native_HG_GameStart(Handle:plugin, numParams)
{
    if( HG_Started )
        return true;
    return false;
}
// Use This For Voice Radius - SetListenOverride(iReceiver, iSender, ListenOverride:override)

/* [ OnGameFrame ] */
