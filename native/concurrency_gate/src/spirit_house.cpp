#include "spirit_house.h"
#include <godot_cpp/core/class_db.hpp>
#include <chrono>
#include <godot_cpp/variant/utility_functions.hpp>	// per le stampe
#include <vector>

using namespace godot;

void SpiritHouse::_bind_methods() {
	ClassDB::bind_method(D_METHOD("request_house"), &SpiritHouse::request_house);
	ClassDB::bind_method(D_METHOD("check_if_available"), &SpiritHouse::check_if_available);
	ClassDB::bind_method(D_METHOD("free_house"), &SpiritHouse::free_house);
	ClassDB::bind_method(D_METHOD("emit_enter_allowed"), &SpiritHouse::emit_enter_allowed);
	
	ADD_SIGNAL(MethodInfo("enter_allowed", PropertyInfo(Variant::INT, "id")));
}

void SpiritHouse::_ready() {
	current_id = -1;
}

void SpiritHouse::emit_enter_allowed(int64_t id) {
	emit_signal("enter_allowed", id);
}

void SpiritHouse::request_house(int64_t id) {
	std::unique_lock<std::mutex> lock(m);
	
	bool check = false;
	for (int i = 0; i < players.size(); i++) {
		if (players[i].id == id) {
			UtilityFunctions::print("sei già prenotato");
			check = true;
		}
	}
	
	if (!check) {
		PlayerHouse plr;
		plr.id = id;
		players.push_back(std::move(plr));	// aggiungo prima l'elemento altrimenti appena aggiungo il thread parte subito
		players.back().thread = std::thread(&SpiritHouse::check_if_available, this, id);
	}
}

void SpiritHouse::check_if_available(int64_t id) {	// faccio girare il thread qui
	std::unique_lock<std::mutex> lock(m);
	
	while(current_id != -1) {
		cv.wait(lock);	// area già occupata
	}
	
	current_id = id;
	call_deferred("emit_enter_allowed", id);
}

void SpiritHouse::free_house(int64_t id) {	// quando esco pulisco il mio thread e notifico se qualcuno è in attesa	
	std::unique_lock<std::mutex> lock(m);
	
	if (id == current_id) {
		current_id = -1;
		
		for (int i = 0; i < players.size(); i++) {
			if (players[i].id == id) {
				UtilityFunctions::print("id trovatro");
				if (players[i].thread.joinable()) {
					players[i].thread.join();
				}
				players.erase(players.begin() + i);
				break;
			}
		}
		
		cv.notify_one();
	}
	
	UtilityFunctions::print(players.size());
}
