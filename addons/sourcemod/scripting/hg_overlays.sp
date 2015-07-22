#include <sourcemod>
#include <smlib>

public OnPluginStart()
{
	RegAdminCmd("sm_overlay", CallBack_Overlay, ADMFLAG_KICK, "");
	RegAdminCmd("sm_remove", CallBack_Remove, ADMFLAG_KICK, "");
}

public OnMapStart()
{
	AddFileToDownloadsTable("materials/overlays/hg/district1sealtest2.vmt");
	AddFileToDownloadsTable("materials/overlays/hg/district1sealtest2.vtf");
}

public Action:CallBack_Overlay(client, args)
{
    ClientCommand(client, "r_screenoverlay \"overlays/hg/district1sealtest2\"");

    return Plugin_Handled;
}

public Action:CallBack_Remove(client, args)
{
    ClientCommand(client, "r_screenoverlay \"\"");

    return Plugin_Handled;
}
