# Events.gd — Central signal bus Autoload
# Pure relay, no business logic. All cross-system signals route through here.
# See ADR-ARCH-001 for full signal directory.
extends Node

# Input signals
signal input_action(player_id: int, action: StringName, strength: float)
signal input_cleared  # Emitted when game window loses focus — all input state must be reset
signal device_mode_changed(player_id: int, mode: StringName)  # &"gamepad" or &"keyboard"
signal device_status_message(player_id: int, message: String)  # for UI toast
signal device_assigned(player_id: int, device_index: int)  # emitted when gamepad assigned to P1/P2

# Combat signals
signal rescue_input(player_id: int)
signal dodge_input(player_id: int)
signal sync_attack_detected()

signal attack_hit(attack_id: int, is_grounded: bool, hit_count: int)
signal attack_started(attack_type: String)
signal hit_confirmed(hitbox_id: int, hurtbox_id: int, attack_id: int)
signal hurt_received(damage: int, knockback: Vector2)

# Combo signals
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)  ## From CombatManager on each hit
signal combo_multiplier_updated(multiplier: float, player_id: int)  ## From ComboManager
signal combo_tier_changed(tier: int, player_id: int)  ## From ComboManager when tier changes
signal combo_tier_escalated(tier: int, player_color: Color)  ## From ComboManager on tier transition
signal combo_break(player_id: int)  ## From ComboManager when combo resets
signal combo_tier_audio(tier: int)  ## From ComboManager for audio tier sounds
signal sync_chain_active(chain_length: int)  ## From ComboManager (0 = broken)
signal sync_burst_triggered(position: Vector2)  ## From ComboManager at 3+ consecutive SYNC
signal sync_window_opened(player_id: int, partner_id: int)  ## From ComboManager

# Coop signals
signal player_damaged(player_id: int, damage: int)  ## From CoopManager on damage
signal player_healed(player_id: int, amount: int)  ## From CoopManager on heal
signal player_hp_changed(player_id: int, current: int, max: int)  ## From CoopManager on any HP change
signal player_downed(player_id: int)
signal player_rescued(player_id: int, rescuer_color: Color)
signal rescue_triggered(position: Vector2, rescuer_color: Color)  ## From CoopManager on rescue trigger
signal crisis_state_changed(is_crisis: bool)
signal coop_bonus_active(multiplier: float)
signal solo_mode_active(player_id: int)

# Boss signals
signal boss_attack_started(attack_pattern: String)
signal boss_phase_changed(new_phase: int)
signal boss_hp_changed(current: int, max: int)
signal boss_defeated(position: Vector2, boss_type: String)

# Camera signals
signal camera_shake_intensity(trauma: float)
signal camera_zoom_changed(zoom: float)
signal camera_framed_players(positions: Array[Vector2])

# Arena signals
signal arena_changed(arena_id: String, bounds: Dictionary)

# Game state signals
signal game_over()