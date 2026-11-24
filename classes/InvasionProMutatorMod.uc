//=======================================================
// InvasionProMutatorMod
//
// Fixed Tick() for InvasionProMutator, used by InvasionProMod.
//
// WHY: the stock InvasionProMutator.Tick force-assigns
//   bTeamLocked = false; bNoFriendlyFire = true; Team = 0;
// to EVERY vehicle on the map every frame. For VEHICLE MONSTERS
// (VehicleMonstersV1) this was fatal:
//   * the monster sets its vehicle Team=255 (hostile/teamless),
//     but the mutator overwrote it back to 0 within a frame
//   * Team 0 = the player/bot team -> the LINK GUN heals the
//     vehicle (TeamLink matches) and player damage is zeroed
//     (same-team + FriendlyFireScale=0 in ReduceDamage)
// This override skips the vehicle handling for vehicles driven
// by VehicleMonster pawns, keeping them teamless (255) and
// damageable, while preserving stock behavior for every other
// vehicle (player vehicles etc).
//
// The VehicleMonster class is resolved at runtime (the mod
// package cannot compile-time depend on VehicleMonstersV1).
//=======================================================
class InvasionProMutatorMod extends InvasionProMutator;

var class<Monster> VehicleMonsterClass; // resolved at runtime

//True for the 12 VehicleMonstersV1 vehicle shells (all named
//"VehicleMonsterVeh..."): keeps abandoned/wrecked monster vehicles teamless
//so the link gun can't heal them and players can still damage them.
function bool IsVehicleMonsterShell(Vehicle V)
{
	return (V != None && Left(string(V.Class.Name), 16) ~= "VehicleMonsterVeh");
}

//Admin toggle for RPG-themed bot team chat: "mutate botchatter"
simulated function Mutate(string MutateString, PlayerController Sender)
{
	local InvasionProMod G;
	local string OnOff;

	if (MutateString ~= "botchatter" && Sender != None && (Level.Netmode == NM_Standalone || Sender.PlayerReplicationInfo.bAdmin))
	{
		G = InvasionProMod(Level.Game);
		if (G != None)
		{
			G.bBotChatter = !G.bBotChatter;
			G.SaveConfig();
			OnOff = "OFF";
			if (G.bBotChatter)
				OnOff = "ON";
			Broadcast("Admin set bot chatter " $ OnOff);
		}
	}

	Super.Mutate(MutateString, Sender);
}

function Tick(float DeltaTime)
{
	local Actor A;
	local InvasionProFriendlyMonsterReplicationInfo PRI;
	local Inventory Inv;

	//Resolve the VehicleMonster class once (no compile-time dependency
	//on the VehicleMonstersV1 package).
	if( VehicleMonsterClass == None )
		VehicleMonsterClass = class<Monster>(DynamicLoadObject("VehicleMonstersV1.VehicleMonster", class'Class', true));

	foreach DynamicActors(class'Actor',A)
	{
		if(Vehicle(A) != None)
		{
			//Vehicle monsters: hold the vehicle at BLUE TEAM (1) so its skins
			//render (TeamChanged only applies Red/Blue skins for teams 0/1 -
			//team 255 leaves hull/turrets on their default material = missing-
			//texture green). Players/bots are team 0 (red) in Invasion, so
			//team 1 also means the link gun can't heal them and same-team
			//damage blocking never applies. Skip ALL stock vehicle overrides
			//for them (bTeamLocked is already false, set by VehicleMonster.
			//Timer before entry).
			//
			//ABANDONED MONSTER VEHICLES (Driver==None - driver died, wreck
			//waiting to despawn): the stock check below would otherwise
			//classify them as player vehicles and force Team=0 - which made
			//bots able to HEAL the wreck with the link gun. Our shells are
			//identifiable by class name prefix ("VehicleMonsterVeh...") - all
			//12 of them - so treat those as monster vehicles even driverless.
			if( (Vehicle(A).Driver == None
					|| VehicleMonsterClass == None
					|| !ClassIsChildOf(Vehicle(A).Driver.Class, VehicleMonsterClass))
				&& !IsVehicleMonsterShell(Vehicle(A)) )
			{
				Vehicle(A).bTeamLocked = false;
				Vehicle(A).bNoFriendlyFire = true;
				Vehicle(A).Team = 0;
			}
			else
			{
				//Only re-assert the team when it CHANGED (2026-08-08): stock
				//ONSVehicle.SetTeamNum loops WeaponPawns and "Accessed None
				//'WeaponPawns'"-spams every call when a turret seat was
				//destroyed in combat - calling it every frame flooded the
				//server log. Team==1 is already the steady state after the
				//first call; this still re-asserts it if anything resets the
				//team (e.g. the stock mutator path above after a respawn).
				if( Vehicle(A).Team != 1 )
					Vehicle(A).SetTeamNum(1);
			}
		}
		else if(Monster(A) != None && Monster(A).Controller != None && Monster(A).PlayerReplicationInfo != None && InvasionProFriendlyMonsterReplicationInfo(Monster(A).PlayerReplicationInfo) == None && Monster(A).PlayerReplicationInfo.Class.Name != 'FriendlyPawnPlayerReplicationInfo')
		{
			//TitanRPG summons use FriendlyPawnPlayerReplicationInfo; adopting them shows an extra cyan "Owner's Monster" label
			PRI = Spawn(class'InvasionProFriendlyMonsterReplicationInfo');
			if(PRI != None)
			{
				PRI.PlayerName = Monster(A).PlayerReplicationInfo.PlayerName;
				PRI.Team = Monster(A).PlayerReplicationInfo.Team;
				PRI.SetPRI();
				Monster(A).PlayerReplicationInfo.Destroy();
				Monster(A).PlayerReplicationInfo = PRI;
				Monster(A).Controller.PlayerReplicationInfo = PRI;
				InvasionPro(Level.Game).UpdatePlayerGRI();
				if(InvasionProGameReplicationInfo(Level.Game.GameReplicationInfo) != None)
				{
					InvasionProGameReplicationInfo(Level.Game.GameReplicationInfo).AddFriendlyMonster(Monster(A));
				}
			}

			Inv = Monster(A).FindInventoryType(class'InvasionProMonsterIDInv');

			if(InvasionProMonsterIDInv(Inv) != None)
			{
				InvasionProMonsterIDInv(Inv).bFriendly = true;
			}
		}
	}
}

defaultproperties
{
}
