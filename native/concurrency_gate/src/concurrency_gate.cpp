#include "concurrency_gate.h"
#include <godot_cpp/core/class_db.hpp>
#include <chrono>

using namespace godot;

void ConcurrencyGate::_bind_methods() {
	ClassDB::bind_method(D_METHOD("player_try_acquire_mutex"), &ConcurrencyGate::player_try_acquire_mutex);
	ClassDB::bind_method(D_METHOD("player_release_mutex"), &ConcurrencyGate::player_release_mutex);
}

void ConcurrencyGate::_exit_tree() {
	// se il player sta tenendo il mutex, lo rilascia
	if (player_id_holds != -1) {
		player_id_holds = -1;
		gate_mutex.unlock();
	}
}

bool ConcurrencyGate::player_try_acquire_mutex(int64_t id) {
	if (player_id_holds == id) {
		return true;
	}
	if (gate_mutex.try_lock()) {
		player_id_holds = id;
		return true;
	}
	return false;
}

void ConcurrencyGate::player_release_mutex(int64_t id) {
	if (player_id_holds != id) {
		return;
	}
	player_id_holds = -1;
	gate_mutex.unlock();
}
