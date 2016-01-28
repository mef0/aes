/*
*	AES: Level System		Reloaded v1
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <amxmisc>

#include <aes_r>
#include <aes_level>

#define PLUGIN "AES: Level System"
#define VERSION "Reloaded v1 Dev 1"
#define AUTHOR "serfreeman1337"

// --- КОНСТАНТЫ --- //

enum _:FIELDS_TYPE	// список полей
{
	EXP,
	LEVEL,
	EXP_TO_NEXT,
	MAXLEVEL
}

enum _:CVARS_LIST
{
	CVAR_LEVELS
}

new const fields_set[FIELDS_TYPE][][] = {	// описание полей
	{"exp",1,true},			// поле опыта, сохраняем
	{"level",1,false},		// поле уровня, не сохраняем
	{"expnext",1,false},		// поле опыта до сл. уровня, не сохраняем
	{"maxlevel",1,false}		// поле макс. уровня, не сохраняем
}

// --- ПЕРЕМЕННЫЕ --- //

new fields_id[FIELDS_TYPE]
new cvar[CVARS_LIST]

new Array:levels_list			// массив с описанием уровней
new levels_count				// кол-во уровней
new Float:max_exp

public plugin_init(){
	register_plugin(PLUGIN,VERSION,AUTHOR)

	// регистрируем поля статистики в AES
	for(new i ; i < FIELDS_TYPE ; i++)
	{
		fields_id[i] = aes_field_register(
			fields_set[i][0],
			fields_set[i][1][0],
			bool:fields_set[i][2][0]
		)
	}
	
	cvar[CVAR_LEVELS] = register_cvar("aes_level","0 20 40 60 100 150 200 300 400 600 1000 1500 2100 2700 3400 4200 5100 5900 7000 10000")

	aes_field_register_forward(fields_id[EXP],"EXP_Handler")
	aes_field_register_forward(fields_id[LEVEL],"LEVEL_Handler")
	
	register_dictionary("aes_level.txt")
	
	register_clcmd("test","test")
}

public test(id)
{
	new field_id,field_name[10],field_size,for_save,r
	
	while((field_id = aes_field_list(field_id,field_name,charsmax(field_name),field_size,for_save)) != -1)
	{
		server_print("--> [%d] for [%s][%d][%d]",
			field_id,field_name,field_size,for_save
		)
		
		r++
		
		if(r > 5)
			break
	}
}

public plugin_cfg()
{
	// выполняем загрузку файла конфигурации
	new cfg_path[256]
	get_configsdir(cfg_path,charsmax(cfg_path))
	
	server_cmd("exec %s/aes/aes.cfg",cfg_path)
	server_exec()
	
	new levels_string[512],level_str[10]
	get_pcvar_string(cvar[CVAR_LEVELS],levels_string,charsmax(levels_string))
	
	while((argbreak(levels_string,level_str,charsmax(level_str),levels_string,charsmax(levels_string))) != -1)
	{
		if(!levels_list)
		{
			levels_list = ArrayCreate(1)
		}
		
		ArrayPushCell(levels_list,floatstr(level_str))
		max_exp = floatstr(level_str)
	}
	
	if(levels_list)
		levels_count = ArraySize(levels_list)
		
	server_print("--> TOTAL LEVELS: %d",levels_count)

}

public EXP_Handler(player,field_id,Float:new_exp,Float:old_exp)
{
	if(!(0.0 <= new_exp <= max_exp))
	{
		new_exp = floatclamp(new_exp,0.0,max_exp)
		aes_field_set(player,fields_id[EXP],new_exp)
	}
	
	new level = aes_field_get(player,fields_id[LEVEL])
	new Float:level_exp = Level_GetExp(level)
	
	// обновляем информацию, если опыт не соотв. уровеню
	if(new_exp < level_exp || new_exp >= aes_field_get(player,fields_id[EXP_TO_NEXT]))
	{
		server_print("--> [EXP] UPDATE BY FORWARD %d",player)
		Player_RefreshInfo(player)
	}
	
	return PLUGIN_CONTINUE
}

public LEVEL_Handler(player,field_id,new_level,old_level)
{
	if(new_level == -1)
	{
		return PLUGIN_HANDLED
	}
	
	new Float:level_exp = Level_GetExp(new_level)
	new Float:player_exp = aes_field_get(player,fields_id[EXP])
	
	server_print("--> [LEVEL] %d %d %d",
		player_exp,level_exp,Level_GetExpToNext(new_level)
	)
	
	if(!(level_exp <= player_exp < Level_GetExpToNext(new_level)))
	{
		aes_field_set(player,fields_id[EXP],level_exp)
	}
	
	return PLUGIN_CONTINUE
}


Player_RefreshInfo(player)
{
	new Float:exp = aes_field_get(player,fields_id[EXP])
	
	new level = Level_GetByExp(exp)
	new Float:expnext = Level_GetExpToNext(level)
	
	aes_field_set(player,fields_id[LEVEL],level)
	aes_field_set(player,fields_id[EXP_TO_NEXT],expnext)
	aes_field_set(player,fields_id[MAXLEVEL],levels_count)
	
	server_print("--> REFRESH [%d] EXP:%d/%d LEVEL:%d",
		player,exp,expnext,level)
	
}

//
// Функция возвращается текущий уровень по значению опыта
//
Level_GetByExp(Float:exp)
{
	for(new i ; i < levels_count ; i++)
	{
		// ищем уровень по опыту
		if(exp < ArrayGetCell(levels_list,i))
		{
			server_print("--> [LIST] %d %d %d",
				i,exp,ArrayGetCell(levels_list,i)
			)
			
			return clamp(i  - 1,0,levels_count - 1)
		}
	}
	
	// возвращаем максимальный уровень
	return levels_count - 1
}

//
// Функция возвращает необходимый опыт до сл. уровня
//
any:Level_GetExpToNext(level)
{
	level ++
	
	// достигнут максимальный уровень
	if(level >= levels_count)
	{
		return -1.0
	}

	// TODO: проверки
	level = clamp(level,0,levels_count - 1)
	
	return ArrayGetCell(levels_list,level)
}

//
// Функция возвращает опыт для указанного уровня
//
any:Level_GetExp(level)
{
	// TODO: проверки
	if(level == -1)
		return -1.0
	
	return ArrayGetCell(levels_list,level)
}

//
// --- API --- //
//



public plugin_natives()
{
	register_library("aes_level")
	
	register_native("aes_get_level_name","native_aes_get_level_name")
	register_native("aes_get_exp_to_next_level","native_aes_get_exp_to_next_level")
	register_native("aes_get_max_level","native_aes_get_max_level")
	register_native("aes_get_max_exp","native_aes_get_max_exp")
}

public native_aes_get_level_name(plugin_id,params)
{
	new level = get_param(1)
	new idLang = get_param(4)
	
	level = clamp(level,0,levels_count)
		
	new LangKey[10],levelName[64]
	
	formatex(LangKey,charsmax(LangKey),"%d",level)
	
	formatex(LangKey,charsmax(LangKey),"LVL_%d",level + 1)
	formatex(levelName,charsmax(levelName),"%L",idLang,LangKey)
	
	set_string(2,levelName,get_param(3))
	
	return true
}

public native_aes_get_exp_to_next_level(plugin_id,params)
{
	new level = get_param(1)
	
	return Level_GetExpToNext(level)
}

public native_aes_get_max_level(plugin_id,params)
{
	return levels_count
}

public Float:native_aes_get_max_exp(plugin_id,params)
{
	return max_exp
}