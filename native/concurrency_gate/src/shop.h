#pragma once
#include <godot_cpp/classes/node.hpp>
#include <mutex>
#include <thread>
#include <atomic>

namespace godot {

class Shop : public Node {
	GDCLASS(Shop, Node);

	std::mutex m;

protected:
	static void _bind_methods();

public:
	bool lock_mutex();
	void unlock_mutex();
};

} // namespace godot
