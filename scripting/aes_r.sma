/*
*	Advanced Experience System	    Reloaded v1
*	by serfreeman1337		http://1337.uz/
*/

#include <amxmodx>

#define PLUGIN "Advanced Experience System"
#define VERSION "Reloaded v1 Dev 1"
#define AUTHOR "serfreeman1337"

// --- КОНСТАНТЫ --- //

// --- ПЕРМЕННЫЕ --- //

new Array:field_list			// динамический массив с ID всех полей статистики
new Array:field_forwards			// динимический массив с динамическим массивом форвадов всех полей статистики
new Array:player_stats[MAX_PLAYERS]	// динамический массив со статистикой игроков

new field_maxsize,fields_count

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
}

public plugin_natives()
{
	register_native("aes_field_register","native_aes_field_register")
	register_native("aes_field_list","native_aes_field_list")
	register_native("aes_field_set","native_aes_field_set")
	register_native("aes_field_get","native_aes_field_get")
	register_native("aes_field_register_forward","native_aes_field_register_forward")
}

//
// Обработчик натива регистрации поля статистики
//
//	native aes_field_register(field_name[],field_size = 1,bool:allow_save = true)
public native_aes_field_register(plugin_id,params)
{
	new field_name[10],field_size = 1,bool:field_save = true
	
	get_string(1,field_name,charsmax(field_name))
	
	// размер поля
	if(params >= 2)
	{
		field_size = get_param(2)
	}
	
	// свитч отвечающий за сохранение
	if(params >= 3)
	{
		field_save = bool:get_param(3)
	}
	
	// регистрируем поле и возрващаем его ID
	new field_id = AES_FieldRegister(field_name,field_size,field_save)
	
	return field_id
}

//
// Устанавливаем значение поля статистики для игрока
//
//	native aes_field_set(player,field_id,any:value)
public native_aes_field_set(plugin_id,params)
{
	new player = get_param(1)
	new field_id = get_param(2)
	
	new any:value = any:get_param(3)
	
	return AES_StatSet(player,field_id,value)
}

//
// Считываем значение поля статистики у игрока
//
//	native any:aes_field_get(player,field_id)
public native_aes_field_get(plugin_id,params)
{
	new player = get_param(1)
	new field_id = get_param(2)
	
	return AES_StatRead(player,field_id)
}

//
// Устанавливаем форвард для поля
//
//	public forward(player,field_id,any:new,any:old)
// 	native aes_field_register_forward(field_id,callback[])
public native_aes_field_register_forward(plugin_id,params)
{
	new field_id = get_param(1)
	
	new callback[20]
	get_string(2,callback,charsmax(callback))
	
	new Array:forwards_array = ArrayGetCell(field_forwards,field_id)
	
	if(forwards_array == Invalid_Array)
		forwards_array = ArrayCreate(1)
		
	// player, new value, old value
	new forward_id = CreateOneForward(plugin_id,callback,FP_CELL,FP_CELL,FP_CELL,FP_CELL)
	
	ArrayPushCell(forwards_array,forward_id)
	ArraySetCell(field_forwards,field_id,forwards_array)
	
	return true
}

public native_aes_field_list(plugin_id,params)
{
	new index = get_param(1)
	
	server_print("--------------> %d",index)
	
	if(!(0 <= index < fields_count))
		return -1
	
	for(new field_desc[12],i = index ; index < fields_count ; i++)
	{
		ArrayGetArray(field_list,i,field_desc)
		
		server_print("-----> index: %d, field_count: %d, size: %d, save: %d  [%s]",i,fields_count,field_desc[0],field_desc[1],field_desc[2])
		
		set_param_byref(4,field_desc[0])
		set_param_byref(5,field_desc[1])
		set_string(2,field_desc[2],get_param(3))
		
		return i + 1
	}
	
	return -1
}

public client_putinserver(player)
{
	AES_StatInit(player)
}

//
// Задаем значение поля
//
AES_StatSet(player,field_id,any:value)
{
	if(!player_stats[player])
		return false
		
	new Array:forwards_array = ArrayGetCell(field_forwards,field_id)
	
	if(forwards_array != Invalid_Array)
	{
		new any:old_val = AES_StatRead(player,field_id)
		
		// вызываем форварды при изменении статистики
		if(value != old_val)
		{
			new forward_ret
			
			for(new i,length = ArraySize(forwards_array) ; i < length ; i++)
			{
				new forward_id = ArrayGetCell(forwards_array,i)
				
				ArraySetCell(player_stats[player],field_id,value)
				
				ExecuteForward(forward_id,forward_ret,player,field_id,value,old_val)
				
				if(forward_ret == PLUGIN_HANDLED)
				{
					// возвращаем всё как было
					ArraySetCell(player_stats[player],field_id,old_val)
					
					return false
				}
			}
		}
	}
	
	// мне лень разделять форварды на pre и post
	return forwards_array == Invalid_Array ? ArraySetCell(player_stats[player],field_id,value) : 1
}

//
// Считываем значение поля
//
_:AES_StatRead(player,field_id)
{
	if(!player_stats[player])
		return false
	
	return ArrayGetCell(player_stats[player],field_id)
}

//
// Загружаем статистику пользователя
//
AES_StatInit(player)
{
	if(!field_maxsize)
		return false
	
	if(player_stats[player])
	{
		ArrayClear(player_stats[player])
	}
	else
	{
		player_stats[player] = ArrayCreate(field_maxsize)
	}
	
	for(new i ; i < fields_count ; i++)
	{
		ArrayPushCell(player_stats[player],0)
	}
	
	/*new field_id,field_name[10],field_size
	
	while((field_id = AES_FieldList(field_id,field_name,charsmax(field_name),field_size)) != -1)
	{
		ArraySetString(
	}*/
	
	return true
}


//
// Регистрируем новое поле статистики
//
AES_FieldRegister(uniqueid[],cellsize = 1,bool:allow_save = true)
{
	
	new field_desc[12]
	
	// создаем новый динамический массив для этого
	if(!field_list)
	{
		field_list = ArrayCreate(sizeof field_desc)
		field_forwards = ArrayCreate(1)
	}
	
	// 1 байт - на размерность поля
	// 2 байт - true или false - не сохранять эту статистику
	// остальные 10 на название поля
	
	field_desc[0] = cellsize
	field_desc[1] = allow_save
	
	copy(field_desc[2],charsmax(field_desc) - 2,uniqueid)
	
	server_print("--> FIELDREG: [%s][%d][%d] ID: %d",
		field_desc[2],
		field_desc[0],
		field_desc[1],
		ArraySize(field_list)
	)
	
	ArrayPushArray(field_list,field_desc)
	ArrayPushCell(field_forwards,Invalid_Array)
	
	if(cellsize > field_maxsize)
	{
		field_maxsize = cellsize
	}
	fields_count = ArraySize(field_list)
	
	return  fields_count - 1
}

/*
AES_FieldList(index,uniqueid[],unique_id_len,&size = 0)
{
	if(!(0 <= index < fields_count))
		return -1
	
	for(new field_desc[11] ; index < fields_count ; index++)
	{
		ArrayGetArray(field_list,index,field_desc)
		
		server_print("--> %d [%s]",index,field_desc[1])
		
		size = field_desc[0]
		copy(uniqueid,unique_id_len,field_desc[1])
		
		return index + 1
	}
	
	return -1
}
*/
