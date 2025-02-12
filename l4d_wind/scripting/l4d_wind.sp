/* Plugin Template generated by Pawn Studio */
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#define CVAR_FLAGS	FCVAR_NOTIFY
static float g_pos[3];

ConVar g_cvAddTopMenu, g_cvAddBot;
TopMenuObject hAdminTeleportItem;
bool g_bMenuAdded;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();

	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "SM Respawn only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "Add a survivor bot + Teleport an alive player",
	author = "Harry Potter",
	description = "Create a survivor bot + teleport an alive player in game",
	version = "1.3",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_wind", sm_addabot, ADMFLAG_BAN, "add a survivor bot");
	RegAdminCmd("sm_addbot", sm_addabot, ADMFLAG_BAN, "add a survivor bot");
	RegAdminCmd("sm_createbot", sm_addabot, ADMFLAG_BAN, "add a survivor bot");

	g_cvAddBot = 	CreateConVar("l4d_wind_add_bot_enable", 	"1", 	"If 1, Adm can use command to add a survivor bot", CVAR_FLAGS);
	g_cvAddTopMenu = 	CreateConVar("l4d_wind_teleport_adminmenu", 	"1", 	"Add 'Teleport player' item in admin menu under 'Player commands' category? (0 - No, 1 - Yes)", CVAR_FLAGS);

	g_cvAddTopMenu.AddChangeHook(OnCvarTopMenuChanged);

	OnAdminMenuReady(null);

	AutoExecConfig(true, "l4d_wind");
}

public Action sm_addabot(int client, int args)
{
	if(g_cvAddBot.BoolValue == false) return Plugin_Handled;

	int bot = CreateFakeClient("I am not real.");
	if(bot != 0)
	{
		ChangeClientTeam(bot, 2);
		if(DispatchKeyValue(bot, "classname", "SurvivorBot") == false)
		{
			PrintToChatAll("\x01[TS] Failed to add a bot");
			return Plugin_Handled;
		}
		
		if(DispatchSpawn(bot) == false)
		{
			PrintToChatAll("\x01[TS] Failed to add a bot");
			return Plugin_Handled;
		}
		SetEntityRenderColor(bot, 128, 0, 0, 255);
 		
		bool canTeleport = SetTeleportEndPoint(client);
		if(canTeleport)
		{
			PerformTeleport(client,bot,g_pos,true);
		}
		
		CreateTimer(0.1, Timer_KickFakeBot, bot, TIMER_REPEAT);
		PrintToChatAll("\x01[TS] Succeed to add a bot, Spectator type \x04!jiaru\x01 to join");
	}
	return Plugin_Handled;
}

public Action sm_join(int client, int args)
{
	if(GetClientTeam(client) == 1)
		FakeClientCommand(client, "jointeam 2");
	else
		PrintToChat(client,"\x01[TS] You are not Spectator...");
 	return Plugin_Handled;
}


static bool SetTeleportEndPoint(int client)
{
	float vAngles[3],vOrigin[3];
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	//get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		float vBuffer[3],vStart[3];

		TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		float Distance = -35.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		PrintToChat(client, "[TS] %s", "Could not teleport player after create a bot");
		delete trace;
		return false;
	}
	delete trace;
	return true;
}

void PerformTeleport(int client, int target, float pos[3], bool addbot = false)
{
	pos[2] += 5.0;
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	
	if(addbot)
		LogAction(client,target, "\"%L\" teleported \"%L\" after respawn him (New bot)." , client, target);
	else
		LogAction(client,target, "\"%L\" teleported \"%L\"" , client, target);
}


public Action Timer_KickFakeBot(Handle timer, int fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient");	
		return Plugin_Stop;
	}	
	return Plugin_Continue;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
} 

public void OnCvarTopMenuChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RemoveAdminItem();
	if( convar.BoolValue == true )
	{
		OnAdminMenuReady(null);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "adminmenu") == 0 )
	{
		g_bMenuAdded = false;
		hAdminTeleportItem = INVALID_TOPMENUOBJECT;
	}
}

public void OnAdminMenuReady(Handle hTopMenu)
{
	AddAdminItem(hTopMenu);
}

void RemoveAdminItem()
{
	AddAdminItem(null, true);
}

void AddAdminItem(Handle hTopMenu, bool bRemoveItem = false)
{
	TopMenu hAdminMenu;
	
	if( hTopMenu != null )
	{
		hAdminMenu = TopMenu.FromHandle(hTopMenu);
	}
	else {
		if( !LibraryExists("adminmenu") )
		{
			return;
		}	
		if( null == (hAdminMenu = GetAdminTopMenu()) )
		{
			return;
		}
	}
	
	if( g_bMenuAdded )
	{
		if( (bRemoveItem || !g_cvAddTopMenu.BoolValue) && hAdminTeleportItem != INVALID_TOPMENUOBJECT )
		{
			hAdminMenu.Remove(hAdminTeleportItem);
			g_bMenuAdded = false;
		}
	}
	else {
		if( g_cvAddTopMenu.BoolValue )
		{
			TopMenuObject hMenuCategory = hAdminMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

			if( hMenuCategory )
			{
				hAdminTeleportItem = hAdminMenu.AddItem("L4D_SM_TeleportPlayer_Item", AdminMenuTeleportHandler, hMenuCategory, "sm_teleport", ADMFLAG_BAN, "Teleport an alive player at your crosshair");
				g_bMenuAdded = true;
			}
		}
	}
}

public void AdminMenuTeleportHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if( action == TopMenuAction_SelectOption )
	{
		MenuClientsToTeleport(param);
	}
	else if( action == TopMenuAction_DisplayOption )
	{
		FormatEx(buffer, maxlength, "Teleport Player");
	}
}

void MenuClientsToTeleport(int client, int item = 0)
{
	Menu menu = new Menu(MenuHandler_MenuList, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Player List");

	static char sId[16], name[64];
	bool bNoOneAlive = true;
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && i != client)
		{
			if(!IsPlayerAlive(i)) continue;
			
			FormatEx(sId, sizeof sId, "%i", GetClientUserId(i));
			FormatEx(name, sizeof name, "%N", i);
			
			menu.AddItem(sId, name);
			
			bNoOneAlive = false;
		}
	}
	if(bNoOneAlive) menu.AddItem("1.", "There Are No Any alive player.");
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuList(Menu menu, MenuAction action, int param1, int param2)
{
	switch( action )
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Select:
		{
			int client = param1;
			int ItemIndex = param2;
			
			static char sUserId[16];
			menu.GetItem(ItemIndex, sUserId, sizeof sUserId);
			
			int UserId = StringToInt(sUserId);
			int target = GetClientOfUserId(UserId);
			
			if( target && IsClientInGame(target) && IsPlayerAlive(target))
			{
				if( GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ) 
				{
					PrintToChat(client, "\x01[TS] Target is hanging from ledge, you can't teleport %N .", target);
				}
				else
				{
					bool canTeleport = SetTeleportEndPoint(client);
					if(canTeleport)
					{
						PerformTeleport(client,target,g_pos);
						PrintToChat(client, "\x01[TS] You teleport player %N .", target);
					}
				}
			}
			else
			{
				PrintToChatAll("\x01[TS] Target is not a valid alive player.");
			}

			MenuClientsToTeleport(client, menu.Selection);
		}
	}
}