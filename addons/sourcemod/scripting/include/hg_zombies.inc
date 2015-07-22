#if defined _hg_zombies_included
 #endinput
#endif
#define _hg_zombies_included

native bool:HG_IsZombie(client);
native bool:HG_IsHuman(client);

native HG_ChangeToZombie(client, bool:respawn = false);
native HG_ChangeToHuman(client);
native HG_GetClass(client);

