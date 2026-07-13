#pragma once
#include <godot_cpp/classes/node.hpp>
#include <mutex>
#include <thread>
#include <atomic>

namespace godot {

class ConcurrencyGate : public Node {
	GDCLASS(ConcurrencyGate, Node);

	std::mutex gate_mutex;
	int64_t player_id_holds = -1;

protected:
	static void _bind_methods();

public:
	void _exit_tree() override;

	bool player_try_acquire_mutex(int64_t id); // non blocca: usa try_lock
	void player_release_mutex(int64_t id);
};

} // namespace godot
