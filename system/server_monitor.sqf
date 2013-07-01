private ["_result","_status","_val","_pos","_wsDone","_dir","_block","_isOK","_countr","_objWpnTypes","_objWpnQty","_dam","_selection","_totalvehicles","_object","_idKey","_type","_ownerID","_worldspace","_intentory","_hitPoints","_fuel","_damage","_date","_id","_script","_key","_myArray","_outcome","_vehLimit"];
[]execVM "\z\addons\dayz_server\system\s_fps.sqf"; //server monitor FPS (writes each ~181s diag_fps+181s diag_fpsmin*)

dayz_versionNo = 		getText(configFile >> "CfgMods" >> "DayZ" >> "version");
dayz_hiveVersionNo = 	getNumber(configFile >> "CfgMods" >> "DayZ" >> "hiveVersion");
_script = getText(missionConfigFile >> "onPauseScript");

if ((count playableUnits == 0) and !isDedicated) then {
	isSinglePlayer = true;
};

waitUntil{initialized}; //means all the functions are now defined

diag_log "HIVE: Starting";

if (_script != "") then
{
	diag_log "MISSION: File Updated";
} else {
	while {true} do
	{
		diag_log "MISSION: File Needs Updating";
		sleep 1;
	};
};

serverVehicleCounter = [];

//Stream in objects
	/* STREAM OBJECTS */
		//Send the key
		_key = format["CHILD:302:%1:",dayZ_instance];
		_result = _key call server_hiveReadWrite;

		diag_log "HIVE: Request sent";
		
		//Process result
		_status = _result select 0;
		
		_myArray = [];
		if (_status == "ObjectStreamStart") then {
			_val = _result select 1;
			//Stream Objects
			diag_log ("HIVE: Commence Object Streaming...");
			for "_i" from 1 to _val do {
				_result = _key call server_hiveReadWrite;

				_status = _result select 0;
				_myArray set [count _myArray,_result];
				//diag_log ("HIVE: Loop ");
			};
			//diag_log ("HIVE: Streamed " + str(_val) + " objects");
		};
	
		_countr = 0;	
		_totalvehicles = 0;
		{
				
			//Parse Array
			_countr = _countr + 1;
		
			_idKey = 	_x select 1;
			_type =		_x select 2;
			_ownerID = 	_x select 3;

			_worldspace = _x select 4;
			_intentory=	_x select 5;
			_hitPoints=	_x select 6;
			_fuel =		_x select 7;
			_damage = 	_x select 8;

			_dir = 0;
			_pos = [0,0,0];
			_wsDone = false;
			if (count _worldspace >= 2) then
			{
				_dir = _worldspace select 0;
				if (count (_worldspace select 1) == 3) then {
					_pos = _worldspace select 1;
					_wsDone = true;
				}
			};			
			if (!_wsDone) then {
				if (count _worldspace >= 1) then { _dir = _worldspace select 0; };
				_pos = [getMarkerPos "center",0,4000,10,0,2000,0] call BIS_fnc_findSafePos;
				if (count _pos < 3) then { _pos = [_pos select 0,_pos select 1,0]; };
				diag_log ("MOVED OBJ: " + str(_idKey) + " of class " + _type + " to pos: " + str(_pos));
			};

			if (_damage < 1) then {
				diag_log format["OBJ: %1 - %2", _idKey,_type];
				
				//Create it
				_object = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
				_object setVariable ["lastUpdate",time];
				_object setVariable ["ObjectID", _idKey, true];

				// fix for leading zero issues on safe codes after restart
				if (_object isKindOf "VaultStorageLocked") then {
					_codeCount = (count (toArray _ownerID));
					if(_codeCount == 3) then {
						_ownerID = format["0%1", _ownerID];
					};
					if(_codeCount == 2) then {
						_ownerID = format["00%1", _ownerID];
					};
					if(_codeCount == 1) then {
						_ownerID = format["000%1", _ownerID];
					};
				};

				_object setVariable ["CharacterID", _ownerID, true];
				
				clearWeaponCargoGlobal  _object;
				clearMagazineCargoGlobal  _object;
				
				if ((typeOf _object) in dayz_allowedObjects) then {
					_object addMPEventHandler ["MPKilled",{_this call object_handleServerKilled;}];
					// Test disabling simulation server side on buildables only.
					_object enableSimulation false;
				};
				
				_object setdir _dir;
				_object setpos _pos;
				_object setDamage _damage;
				
				if (count _intentory > 0) then {
					if (_object isKindOf "VaultStorageLocked") then {
						// Fill variables with loot
						_object setVariable ["WeaponCargo", (_intentory select 0), true];
						_object setVariable ["MagazineCargo", (_intentory select 1), true];
						_object setVariable ["BackpackCargo", (_intentory select 2), true];
						_object setVariable ["OEMPos", _pos, true];
					} else {

						//Add weapons
						_objWpnTypes = (_intentory select 0) select 0;
						_objWpnQty = (_intentory select 0) select 1;
						_countr = 0;					
						{
							if (_x == "Crossbow") then { _x = "Crossbow_DZ" }; // Convert Crossbow to Crossbow_DZ
							_isOK = 	isClass(configFile >> "CfgWeapons" >> _x);
							if (_isOK) then {
								_block = 	getNumber(configFile >> "CfgWeapons" >> _x >> "stopThis") == 1;
								if (!_block) then {
									_object addWeaponCargoGlobal [_x,(_objWpnQty select _countr)];
								};
							};
							_countr = _countr + 1;
						} forEach _objWpnTypes; 
					
						//Add Magazines
						_objWpnTypes = (_intentory select 1) select 0;
						_objWpnQty = (_intentory select 1) select 1;
						_countr = 0;
						{
							if (_x == "BoltSteel") then { _x = "WoodenArrow" }; // Convert BoltSteel to WoodenArrow
							_isOK = 	isClass(configFile >> "CfgMagazines" >> _x);
							if (_isOK) then {
								_block = 	getNumber(configFile >> "CfgMagazines" >> _x >> "stopThis") == 1;
								if (!_block) then {
									_object addMagazineCargoGlobal [_x,(_objWpnQty select _countr)];
								};
							};
							_countr = _countr + 1;
						} forEach _objWpnTypes;

						//Add Backpacks
						_objWpnTypes = (_intentory select 2) select 0;
						_objWpnQty = (_intentory select 2) select 1;
						_countr = 0;
						{
							_isOK = 	isClass(configFile >> "CfgVehicles" >> _x);
							if (_isOK) then {
								_block = 	getNumber(configFile >> "CfgVehicles" >> _x >> "stopThis") == 1;
								if (!_block) then {
									_object addBackpackCargoGlobal [_x,(_objWpnQty select _countr)];
								};
							};
							_countr = _countr + 1;
						} forEach _objWpnTypes;
					};
				};	
				
				if (_object isKindOf "AllVehicles") then {
					{
						_selection = _x select 0;
						_dam = _x select 1;
						if (_selection in dayZ_explosiveParts and _dam > 0.8) then {_dam = 0.8};
						[_object,_selection,_dam] call object_setFixServer;
					} forEach _hitpoints;

					_object setFuel _fuel;

					if (!((typeOf _object) in dayz_allowedObjects)) then {
						
						_object setvelocity [0,0,1];
						_object call fnc_vehicleEventHandler;			
						
						if(_ownerID != "0") then {
							_object setvehiclelock "locked";
						};
						
						_totalvehicles = _totalvehicles + 1;

						// total each vehicle
						serverVehicleCounter set [count serverVehicleCounter,_type];
					};
				};

				//Monitor the object
				dayz_serverObjectMonitor set [count dayz_serverObjectMonitor,_object];
			};
		} forEach _myArray;
		
	// # END OF STREAMING #

//Set the Time
	//Send request
	_key = "CHILD:307:";
	_result = _key call server_hiveReadWrite;
	_outcome = _result select 0;
	if(_outcome == "PASS") then {
		_date = _result select 1; 
		if(isDedicated) then {
			//["dayzSetDate",_date] call broadcastRpcCallAll;
			setDate _date;
			dayzSetDate = _date;
			publicVariable "dayzSetDate";
		};

		diag_log ("HIVE: Local Time set to " + str(_date));
	};
	
	createCenter civilian;
	if (isDedicated) then {
		endLoadingScreen;
	};	

if (isDedicated) then {
	_id = [] execFSM "\z\addons\dayz_server\system\server_cleanup.fsm";
};


// Custom Configs
if(isnil "MaxVehicleLimit") then {
	MaxVehicleLimit = 50;
};
if(isnil "MaxHeliCrashes") then {
	MaxHeliCrashes = 5;
};
if(isnil "MaxDynamicDebris") then {
	MaxDynamicDebris = 100;
};

// Custon Configs End

//  spawn_vehicles
_vehLimit = MaxVehicleLimit - _totalvehicles;
diag_log ("HIVE: Spawning # of Vehicles: " + str(_vehLimit));
if(_vehLimit > 0) then {
	for "_x" from 1 to _vehLimit do {
		_id = [] spawn spawn_vehicles;
		//waitUntil{scriptDone _id};
	};
};


//  spawn_roadblocks
diag_log ("HIVE: Spawning # of Debris: " + str(MaxDynamicDebris));
for "_x" from 1 to MaxDynamicDebris do {
	_id = [] spawn spawn_roadblocks;
	//waitUntil{scriptDone _id};
};


allowConnection = true;

if(isnil "dayz_MapArea") then {
	dayz_MapArea = 10000;
};
if(isnil "HeliCrashArea") then {
	HeliCrashArea = dayz_MapArea / 2;
};

// [_guaranteedLoot, _randomizedLoot, _frequency, _variance, _spawnChance, _spawnMarker, _spawnRadius, _spawnFire, _fadeFire]
nul = [3, 4, (30 * 60), (15 * 60), 1, 'center', HeliCrashArea, true, false] spawn server_spawnCrashSite;

nul =    [
                6,        //Number of the guaranteed Loot-Piles at the Crashside
                3,        //Number of the random Loot-Piles at the Crashside 3+(1,2,3 or 4)
                (30*60),    //Fixed-Time (in seconds) between each start of a new Chopper
                (15*60),      //Random time (in seconds) added between each start of a new Chopper
                1,        //Spawnchance of the Heli (1 will spawn all possible Choppers, 0.5 only 50% of them)
                'center', //'center' Center-Marker for the Random-Crashpoints, for Chernarus this is a point near Stary
                8000,    // [106,[960.577,3480.34,0.002]]Radius in Meters from the Center-Marker in which the Choppers can crash and get waypoints
                true,    //Should the spawned crashsite burn (at night) & have smoke?
                false,    //Should the flames & smoke fade after a while?
                2,    //RANDOM WP
                3,        //GUARANTEED WP
                1        //Amount of Damage the Heli has to get while in-air to explode before the POC. (0.0001 = Insta-Explode when any damage//bullethit, 1 = Only Explode when completly damaged)
            ] spawn server_spawnAN2;