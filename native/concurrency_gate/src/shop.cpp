#include "shop.h"
#include <godot_cpp/core/class_db.hpp>
#include <chrono>

using namespace godot;

void Shop::_bind_methods() {
	ClassDB::bind_method(D_METHOD("lock_mutex"), &Shop::lock_mutex);
	ClassDB::bind_method(D_METHOD("unlock_mutex"), &Shop::unlock_mutex);
}

bool Shop::lock_mutex() {
	if (m.try_lock()) {
		return true;
	}
	return false;
}

void Shop::unlock_mutex() {
	m.unlock();
}
