#pragma once
#include <godot_cpp/classes/node.hpp>
#include <mutex>
#include <unordered_map>

namespace godot {

class KillArbiter : public Node {
	GDCLASS(KillArbiter, Node);

	std::mutex m;
	std::unordered_map<uint64_t, int> killer_by_zombie; // per ogni zombie memorizzi quale player lo ha ucciso

protected:
	static void _bind_methods();

public:
	bool try_claim_kill(uint64_t zombie_id, int player_id);
	void forget(uint64_t zombie_id);
};

} // namespace godot
