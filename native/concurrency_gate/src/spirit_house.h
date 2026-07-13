#pragma once
#include <godot_cpp/classes/node.hpp>
#include <mutex>
#include <atomic>
#include <thread>
#include <condition_variable>
#include <vector>

namespace godot {

class SpiritHouse : public Node {
	GDCLASS(SpiritHouse, Node);

	std::mutex m;
	
	struct PlayerHouse {
		int64_t id;
		std::thread thread;
	};

	std::vector<PlayerHouse> players;
	std::condition_variable cv;
	int64_t current_id;

protected:
	static void _bind_methods();

public:
	void _ready() override;
	void emit_enter_allowed(int64_t id);
	void request_house(int64_t id);
	void check_if_available(int64_t id);
	void free_house(int64_t id);
};

} // namespace godot
