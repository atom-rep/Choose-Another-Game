#include "kill_arbiter.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void KillArbiter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("try_claim_kill", "zombie_id", "player_id"), &KillArbiter::try_claim_kill);
	ClassDB::bind_method(D_METHOD("forget", "zombie_id"), &KillArbiter::forget);
}

bool KillArbiter::try_claim_kill(uint64_t zombie_id, int player_id) {
	std::lock_guard<std::mutex> lock(m);

	if (killer_by_zombie.find(zombie_id) != killer_by_zombie.end()) {	// se è diverso da end allora già trovato, end è dopo l'ultimo elemento
		return false; // già assegnato
	}
	killer_by_zombie[zombie_id] = player_id;	// se invece è end: allora devo assegnare
	return true;
}

void KillArbiter::forget(uint64_t zombie_id) {
	std::lock_guard<std::mutex> lock(m);
	killer_by_zombie.erase(zombie_id);
}
