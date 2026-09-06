"""Reproducible authored combat resources. Run from repository root."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

def godot(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, str):
        if value.startswith(('Vector2(', 'Color(', 'Rect2(', '&"')):
            return value
        return json.dumps(value)
    return str(value)

def resource(path, class_name, script, fields, attacks=None):
    attacks = attacks or {}
    text = f'[gd_resource type="Resource" script_class="{class_name}" load_steps={2 + bool(attacks) + len(attacks)} format=3]\n\n'
    text += f'[ext_resource type="Script" path="res://scripts/data/{script}.gd" id="1"]\n'
    if attacks:
        text += '[ext_resource type="Script" path="res://scripts/data/attack_data.gd" id="2"]\n'
    for key, values in attacks.items():
        text += f'\n[sub_resource type="Resource" id="{key}"]\nscript = ExtResource("2")\n'
        text += '\n'.join(f'{k} = {godot(v)}' for k, v in values.items()) + '\n'
    text += '\n[resource]\nscript = ExtResource("1")\n'
    text += '\n'.join(f'{k} = {godot(v)}' for k, v in fields.items()) + '\n'
    for key in attacks:
        text += f'{key} = SubResource("{key}")\n'
    output = ROOT / path
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)

def attack(name, startup, active, recovery, damage, wear, kb, offset, size, **kwargs):
    return dict(id=f'&"{name}"', startup=startup, active=active, recovery=recovery,
                damage=damage, component_damage=wear, knockback=f'Vector2{kb}',
                offset=f'Vector2{offset}', size=f'Vector2{size}', **kwargs)

def build():
    characters = [
        ('kuren', dict(display_name='KUREN', role='RUSHDOWN', quote='Never stop moving.', color='Color(0.937, 0.239, 0.345, 1)', energy='Color(1, 0.624, 0.314, 1)', height=170.0, width=74.0, mass=0.87, speed=910.0, acceleration=7900.0, air_acceleration=3100.0, gravity=2650.0, jump_speed=1380.0, air_jump_speed=1120.0, native_weapon='&"burst_knuckle"', native_shell='&"vent_shell"'), [
            attack('kuren_light', .042, .065, .135, 7, 7, (340, -180), (75, -88), (125, 92), movement=200.0),
            attack('kuren_heavy', .145, .085, .23, 18, 19, (1020, -420), (95, -80), (150, 110), breaker=True, hitstop=.08, hitstun=.27, movement=360.0, feedback='&"heavy"'),
            attack('kuren_uppercut', .115, .09, .25, 18, 19, (350, -1190), (40, -142), (120, 175), breaker=True, hitstop=.075, hitstun=.3, feedback='&"heavy"'),
            attack('kuren_slam', .16, .085, .24, 20, 23, (650, -650), (75, -45), (165, 125), breaker=True, target_slot='&"shell"', hitstop=.08, feedback='&"heavy"'),
        ]),
        ('terra', dict(display_name='TERRA', role='HEAVY / GRAPPLER', quote='Hit once. Hit hard.', color='Color(0.443, 0.545, 0.220, 1)', energy='Color(0.78, 0.922, 0.325, 1)', height=205.0, width=106.0, mass=1.45, speed=610.0, acceleration=4100.0, air_acceleration=2050.0, gravity=2800.0, jump_speed=1460.0, air_jump_speed=1260.0, air_boost_speed=1090.0, native_weapon='&"pile_cannon"', native_shell='&"bulwark"'), [
            attack('terra_light', .085, .09, .22, 13, 12, (540, -230), (100, -90), (180, 100)),
            attack('terra_clinch', .235, .11, .34, 29, 27, (600, -1080), (80, -90), (140, 145), breaker=True, hitstop=.11, hitstun=.38, feedback='&"heavy"', movement=130.0),
            attack('terra_uppercut', .22, .11, .34, 27, 25, (350, -1400), (60, -140), (180, 210), breaker=True, hitstop=.1, hitstun=.37, feedback='&"heavy"'),
            attack('terra_slam', .255, .12, .35, 31, 29, (830, -860), (65, -40), (245, 145), breaker=True, target_slot='&"shell"', hitstop=.11, feedback='&"heavy"'),
        ]),
        ('momo', dict(display_name='MOMO', role='TECH / TRICKSTER', quote='Cute is a combat strategy.', color='Color(0.965, 0.569, 0.8, 1)', energy='Color(1, 0.882, 0.941, 1)', height=156.0, width=73.0, mass=0.78, speed=730.0, acceleration=5900.0, air_acceleration=3700.0, gravity=1930.0, jump_speed=1220.0, air_jump_speed=1040.0, native_weapon='&"halo_caster"', native_shell='&"halo_shell"'), [
            attack('momo_light', .06, .075, .18, 8, 9, (370, -245), (102, -82), (190, 72)),
            attack('momo_snare', .17, .095, .28, 16, 20, (400, -620), (105, -65), (180, 105), breaker=True, hitstop=.07, feedback='&"heavy"', delivery='&"snare"', projectile_speed='Vector2(310, -180)', projectile_lifetime=3.0, projectile_radius='Vector2(55, 48)'),
            attack('momo_uppercut', .14, .1, .27, 17, 19, (250, -1070), (50, -130), (160, 170), breaker=True, hitstop=.075, feedback='&"heavy"'),
            attack('momo_slam', .185, .1, .29, 19, 24, (490, -690), (85, -40), (200, 130), breaker=True, target_slot='&"shell"', hitstop=.08, feedback='&"heavy"'),
        ]),
    ]
    for name, fields, moves in characters:
        fields['id'] = f'&"{name}"'
        fields.update({
            'kuren': dict(description='Close the gap. Hit hard.\nKeep the pressure on.', authored_height=271.0, face_region='Rect2(200, 260, 450, 450)'),
            'terra': dict(description='A huge cannon. A mean clinch.\nOwn the landing zone.', authored_height=287.5, portrait_size=3.65, portrait_center_x=.72, face_region='Rect2(100, 210, 440, 440)'),
            'momo': dict(description='Set a snare. Call a repair drone.\nMake their cannon your cannon.', authored_height=295.5, face_region='Rect2(235, 330, 380, 380)'),
        }[name])
        resource(f'characters/{name}.tres', 'MechData', 'mech_data', fields, dict(zip(('light', 'heavy', 'uppercut', 'slam'), moves)))

    weapons = [
        ('arc_blade', 'ARC BLADE', 'BLADE', 'nova', 'Color(0.157,0.459,0.937,1)', 'Color(0.33,0.91,1,1)', .75, 'melee', attack('arc_sweep', .13, .17, .29, 22, 19, (840, -450), (140, -100), (280, 145), breaker=True, movement=600.0, hitstop=.075, feedback='&"blade"')),
        ('burst_knuckle', 'BURST KNUCKLE', 'BURST', 'kuren', 'Color(0.937,0.239,0.345,1)', 'Color(1,0.624,0.314,1)', 1.15, 'rush', attack('burst_rush', .1, .2, .33, 25, 22, (1170, -430), (105, -85), (190, 135), breaker=True, movement=1120.0, hitstop=.085, feedback='&"burst"')),
        ('pile_cannon', 'PILE CANNON', 'CANNON', 'terra', 'Color(0.443,0.545,0.22,1)', 'Color(0.78,0.922,0.325,1)', 1.4, 'projectile', attack('pile_shot', .32, .06, .45, 31, 25, (1380, -480), (150, -100), (150, 95), breaker=True, hitstop=.1, hitstun=.34, feedback='&"cannon"', delivery='&"cannon"', projectile_speed='Vector2(1920, 0)')),
        ('halo_caster', 'HALO CASTER', 'HALO', 'momo', 'Color(0.965,0.569,0.8,1)', 'Color(1,0.882,0.941,1)', 3.0, 'repair', attack('halo_pulse', .2, .1, .26, 12, 14, (470, -360), (110, -90), (210, 130), hitstop=.05, feedback='&"halo"', delivery='&"repair"', projectile_lifetime=1.1)),
    ]
    for name, title, short, donor, color, energy, cooldown, action, move in weapons:
        resource(f'modules/{name}.tres', 'ModuleData', 'module_data', dict(id=f'&"{name}"', display_name=title, short_name=short, donor=f'&"{donor}"', color=color, energy=energy, cooldown=cooldown, action=f'&"{action}"'), {'attack': move})
    for name, title, short, donor, color, energy, modifiers in [
        ('fin_plate', 'FIN PLATE', 'FIN', 'nova', weapons[0][4], weapons[0][5], dict(air_scale=1.17, resistance=.96)),
        ('vent_shell', 'VENT SHELL', 'VENT', 'kuren', weapons[1][4], weapons[1][5], dict(acceleration_scale=1.14, resistance=.92)),
        ('bulwark', 'BULWARK', 'WALL', 'terra', weapons[2][4], weapons[2][5], dict(acceleration_scale=.87, resistance=1.15)),
        ('halo_shell', 'HALO SHELL', 'HALO', 'momo', weapons[3][4], weapons[3][5], dict(hover_bonus=.35, resistance=.94)),
    ]:
        resource(f'modules/{name}.tres', 'ModuleData', 'module_data', dict(id=f'&"{name}"', display_name=title, short_name=short, slot='&"shell"', donor=f'&"{donor}"', color=color, energy=energy, maximum=60.0, **modifiers))
    print('Authored 3 chassis and 8 module resources.')


if __name__ == '__main__':
    build()
