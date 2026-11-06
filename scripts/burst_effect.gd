class_name BurstEffect
extends CPUParticles2D
## 매치한 칸에서 퍼지는 색 파편 한 번 (기획서 7.2장). 수치는 BoardTheme, 다 퍼지면 스스로 사라진다.


## color 파편을 한 번 터뜨린다.
func play(color: Color, theme_data: BoardTheme) -> void:
	amount = maxi(theme_data.burst_count, 1)
	lifetime = theme_data.burst_lifetime
	initial_velocity_min = theme_data.burst_speed * 0.5
	initial_velocity_max = theme_data.burst_speed
	scale_amount_min = theme_data.burst_size * 0.6
	scale_amount_max = theme_data.burst_size
	self.color = color
	finished.connect(queue_free)
	restart()
