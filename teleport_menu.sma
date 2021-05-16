#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

new msgScreenFade;
new gCounterCp[MAX_PLAYERS + 1], gCounterGc[MAX_PLAYERS + 1];
new bool:gCheckpoint[MAX_PLAYERS + 1];
new bool:gEffects[MAX_PLAYERS + 1];
new bool:g_bCpAlternate[MAX_PLAYERS + 1];

new Float:g_fOrigin[MAX_PLAYERS + 1][2][3];
new Float:g_fAngles[MAX_PLAYERS + 1][3];
new Float:g_flLastCmd[MAX_PLAYERS + 1];

new const FL_PLACES = (FL_ONGROUND | FL_PARTIALGROUND | FL_INWATER | FL_CONVEYOR | FL_FLOAT);
new const Float:VEC_DUCK_HULL_MIN[3] = { -16.0, -16.0, -18.0 };
new const Float:VEC_DUCK_HULL_MAX[3] = { 16.0, 16.0, 32.0 };
new const Float:VEC_DUCK_VIEW[3] = { 0.0, 0.0, 12.0 };
new const Float:VEC_NULL[3] = { 0.0, 0.0, 0.0 };

public plugin_init()
{
	register_plugin("Teleport menu", "1.0", "Lovsky");

	RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn");
	msgScreenFade = get_user_msgid("ScreenFade");

	register_clcmd("/teleport", "TeleportMenu");
	register_clcmd("/tp", "TeleportMenu");
	register_clcmd("dr_tp", "TeleportMenu");
	register_clcmd("dr_sl", "SaveLocation");
	register_clcmd("dr_tl", "TeleportLocation");
	register_clcmd("dr_tl2", "LastTeleportLocation");
}

public CBasePlayer_Spawn(id)
{
	gCheckpoint[id] = false;
	gCounterCp[id] = 0;
	gCounterGc[id] = 0;
}

public client_putinserver(id)
{
	gEffects[id] = false;
	g_flLastCmd[id] = 0.0;
}

public client_disconnected(id)
{
	gEffects[id] = false;
}

public TeleportMenu(id)
{
	if (check_duel(id)) return PLUGIN_HANDLED;

	new szText[128];
	formatex(szText, charsmax(szText), "\yTeleport menu:^n\dcp \r%d \w|\d gc \r%d", gCounterCp[id], gCounterGc[id]);
	new menu = menu_create(szText, "handler_menu");

	formatex(szText, charsmax(szText), "Сохранить позицию");
	menu_additem(menu, szText, "1");

	if (gCounterCp[id] > 0)
	{
		formatex(szText, charsmax(szText), "Загрузить позицию \y#%d", gCounterCp[id]);
		menu_additem(menu, szText, "2");
	}

	if (gCounterCp[id] > 1)
	{
		formatex(szText, charsmax(szText), "Загрузить позицию \y#%d", gCounterCp[id] - 1);
		menu_additem(menu, szText, "3");

		formatex(szText, charsmax(szText), "Эффекты \d[\r%s\d]", gEffects[id] ? "OFF" : "ON");
		menu_additem(menu, szText, "4");
	}

	menu_setprop(menu, MPROP_EXITNAME, "Выход");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public handler_menu(id, menu, item)
{
	if (item == MENU_EXIT || !is_user_alive(id) || check_duel(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	item++;
	switch (item)
	{
		case 1: SaveLocation(id);
		case 2: TeleportLocation(id);
		case 3: LastTeleportLocation(id);
		case 4: gEffects[id] = !gEffects[id];
	}

	menu_destroy(menu);
	TeleportMenu(id);
	return PLUGIN_HANDLED;
}

public SaveLocation(id)
{
	if (!is_user_alive(id) || check_duel(id)) return;

	if (!(pev(id, pev_flags) & FL_PLACES))
	{
		client_print(id, print_center, "Запрещено сохранять в данной позиции!");
		return;
	}

	pev(id, pev_origin, g_fOrigin[id][g_bCpAlternate[id] ? 1 : 0]);
	pev(id, pev_v_angle, g_fAngles[id]);
	g_bCpAlternate[id] = !g_bCpAlternate[id];

	gCounterCp[id]++;
	gCheckpoint[id] = true;

	if (!gEffects[id])
	{
		SaveEffect(id);
		client_cmd(id, "speak buttons/blip1");
	}
}

public TeleportLocation(id)
{
	if (!is_user_alive(id) || check_duel(id) || bCheckFlood(id)) return;

	if (gCheckpoint[id])
	{
		if (!gEffects[id]) TeleportEffect(id);

		gCounterGc[id]++;
		TeleportPlayer(id);
	}
}

public LastTeleportLocation(id)
{
	if (!is_user_alive(id) || check_duel(id) || bCheckFlood(id)) return;

	if (gCheckpoint[id])
	{
		if (!gEffects[id]) TeleportEffect(id);

		gCounterGc[id]++;
		LastTeleportPlayer(id);
	}
}

public TeleportPlayer(id)
{
	new vVelocity[3];
	set_pev( id, pev_velocity, vVelocity );
	
	new iFlags = pev(id, pev_flags);
//	iFlags &= ~FL_BASEVELOCITY;
	iFlags |= FL_DUCKING;
	set_pev(id, pev_flags, iFlags);
	engfunc(EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX);
	engfunc(EngFunc_SetOrigin, id, g_fOrigin[id][!g_bCpAlternate[id]]);
	set_pev(id, pev_view_ofs, VEC_DUCK_VIEW);

	set_pev(id, pev_v_angle, VEC_NULL);
//	set_pev(id, pev_basevelocity, VEC_NULL);
	set_pev(id, pev_angles, g_fAngles[id]);
	set_pev(id, pev_punchangle, VEC_NULL);
	set_pev(id, pev_fixangle, 1);

	set_pev(id, pev_fuser2, 0.0);
}

public LastTeleportPlayer(id)
{
	new vVelocity[3];
	set_pev( id, pev_velocity, vVelocity );
	
	new iFlags = pev(id, pev_flags);
//	iFlags &= ~FL_BASEVELOCITY;
	iFlags |= FL_DUCKING;
	set_pev(id, pev_flags, iFlags);
	engfunc(EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX);
	engfunc(EngFunc_SetOrigin, id, g_fOrigin[id][g_bCpAlternate[id]]);
	set_pev(id, pev_view_ofs, VEC_DUCK_VIEW);

	set_pev(id, pev_v_angle, VEC_NULL);
//	set_pev(id, pev_basevelocity, VEC_NULL);
	set_pev(id, pev_angles, g_fAngles[id]);
	set_pev(id, pev_punchangle, VEC_NULL);
	set_pev(id, pev_fixangle, 1);

	set_pev(id, pev_fuser2, 0.0);
}

public SaveEffect(id)
{
	if (!is_user_alive(id)) return;

	message_begin(MSG_ONE, msgScreenFade, { 0, 0, 0 }, id);
	write_short(1 << 10);
	write_short(1 << 10);
	write_short(0x0000);
	write_byte(0);
	write_byte(0);
	write_byte(200);
	write_byte(50);
	message_end();
}

public TeleportEffect(id)
{
	if (!is_user_alive(id)) return;

	message_begin(MSG_ONE, msgScreenFade, { 0, 0, 0 }, id);
	write_short(1 << 10);
	write_short(1 << 10);
	write_short(0x0000);
	write_byte(200);
	write_byte(0);
	write_byte(0);
	write_byte(50);
	message_end();
}

bool:bCheckFlood(id, Float:flDelay = 0.5)
{
	static Float:flTime;
	global_get(glb_time, flTime);

	if (g_flLastCmd[id] + flDelay > flTime) return true;

	g_flLastCmd[id] = flTime + flDelay;
	return false;
}
//Нативы для использования в других плагинах кол телепортов и сохранений
public plugin_natives()
{
	register_native("counter_cp", "native_counter_cp", 1);
	register_native("counter_gc", "native_counter_gc", 1);
}

public native_counter_cp(id)
{
	return gCounterCp[id];
}

public native_counter_gc(id)
{
	return gCounterGc[id];
}
