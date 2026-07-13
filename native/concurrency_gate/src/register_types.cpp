#include "register_types.h"
#include "concurrency_gate.h"
#include "kill_arbiter.h"
#include "shop.h"
#include "spirit_house.h"

using namespace godot;

void initialize_concurrency_gate_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	ClassDB::register_class<ConcurrencyGate>();
	ClassDB::register_class<KillArbiter>();
	ClassDB::register_class<Shop>();
	ClassDB::register_class<SpiritHouse>();
}

void uninitialize_concurrency_gate_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
}
