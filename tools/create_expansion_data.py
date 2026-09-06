"""Original 0.2.0 combat kits; preserves the established eight-module baseline."""
from create_data import resource, attack


def color(hex_value):
    return 'Color(' + ', '.join(str(round(int(hex_value[i:i + 2], 16) / 255, 6)) for i in (0, 2, 4)) + ', 1)'


def build():
    palettes = {
        'shadow': (color('494063'), color('DF74FF')),
        'lumi': (color('F4CD72'), color('ACEEFF')),
        'kai': (color('328ADC'), color('78E9FF')),
        'zero': (color('474551'), color('FF5C77')),
    }
    characters = [
        ('shadow', dict(role='TRICKSTER', quote='You saw that coming. Probably.', description='A tell, a blink, a landing strike.\nSlip around their guard.', height=171.0, width=70.0, mass=.81, speed=865.0, acceleration=7200.0, air_acceleration=3400.0, gravity=2310.0, jump_speed=1360.0, air_jump_speed=1190.0, authored_height=302.0, portrait_size=3.05, portrait_center_x=.35, face_region='Rect2(205, 255, 430, 430)', native_weapon='&"phase_talon"', native_shell='&"mirage_mantle"'), [
            attack('shadow_light', .045, .075, .155, 8, 8, (330, -210), (87, -79), (150, 85), movement=125.0),
            attack('shadow_heavy', .19, .09, .27, 20, 22, (900, -420), (120, -72), (170, 115), breaker=True, movement=340.0, hitstop=.075, feedback='&"heavy"'),
            attack('shadow_uppercut', .14, .10, .29, 19, 21, (240, -1150), (54, -139), (128, 195), breaker=True, feedback='&"heavy"'),
            attack('shadow_slam', .205, .10, .27, 22, 25, (590, -740), (91, -40), (180, 122), breaker=True, target_slot='&"shell"', feedback='&"heavy"'),
        ]),
        ('lumi', dict(role='ZONER', quote='Every angle is covered.', description='Leave a prism in their path.\nMake space, then own it.', height=179.0, width=79.0, mass=.97, speed=685.0, acceleration=5700.0, air_acceleration=3200.0, gravity=2150.0, jump_speed=1310.0, air_jump_speed=1120.0, authored_height=298.0, portrait_size=2.95, portrait_center_x=.40, face_region='Rect2(220, 260, 430, 430)', native_weapon='&"prism_emitter"', native_shell='&"prism_shell"'), [
            attack('lumi_light', .07, .085, .20, 9, 9, (380, -220), (108, -92), (192, 85)),
            attack('lumi_heavy', .225, .12, .30, 21, 23, (910, -420), (147, -89), (232, 128), breaker=True, feedback='&"heavy"'),
            attack('lumi_uppercut', .185, .11, .29, 20, 22, (250, -1210), (62, -145), (183, 202), breaker=True, feedback='&"heavy"'),
            attack('lumi_slam', .24, .12, .31, 24, 26, (650, -790), (93, -39), (223, 125), breaker=True, target_slot='&"shell"', feedback='&"heavy"'),
        ]),
        ('kai', dict(role='GLASS CANNON', quote='One clean shot.', description='Charge up. Commit to the shot.\nHuge power, a fragile frame.', height=177.0, width=71.0, mass=.70, speed=835.0, acceleration=6800.0, air_acceleration=3100.0, gravity=2480.0, jump_speed=1340.0, air_jump_speed=1130.0, incoming_damage_scale=1.12, authored_height=300.0, portrait_size=3.5, portrait_center_x=.69, face_region='Rect2(155, 250, 410, 410)', native_weapon='&"rail_lance"', native_shell='&"flux_frame"'), [
            attack('kai_light', .065, .07, .18, 10, 9, (420, -190), (96, -91), (160, 80)),
            attack('kai_heavy', .24, .09, .36, 27, 27, (1160, -430), (137, -86), (198, 100), breaker=True, hitstop=.09, feedback='&"heavy"'),
            attack('kai_uppercut', .20, .09, .35, 25, 25, (350, -1340), (58, -145), (148, 211), breaker=True, hitstop=.085, feedback='&"heavy"'),
            attack('kai_slam', .265, .095, .34, 29, 29, (850, -770), (113, -42), (208, 125), breaker=True, target_slot='&"shell"', hitstop=.09, feedback='&"heavy"'),
        ]),
        ('zero', dict(role='WILDCARD', quote='Your parts. My rules.', description='Change Special with up or down.\nStolen gear changes your breaker.', height=174.0, width=77.0, mass=.94, speed=775.0, acceleration=6350.0, air_acceleration=3000.0, gravity=2420.0, jump_speed=1330.0, air_jump_speed=1150.0, authored_height=295.0, portrait_size=3.0, portrait_center_x=.40, face_region='Rect2(205, 260, 430, 430)', native_weapon='&"switch_driver"', native_shell='&"adaptive_shell"'), [
            attack('zero_light', .055, .08, .17, 9, 9, (390, -220), (94, -89), (162, 88)),
            attack('zero_heavy', .18, .10, .27, 21, 22, (950, -450), (119, -82), (180, 120), breaker=True, movement=370.0, feedback='&"heavy"'),
            attack('zero_uppercut', .16, .095, .29, 20, 22, (285, -1190), (58, -140), (151, 192), breaker=True, feedback='&"heavy"'),
            attack('zero_slam', .205, .11, .29, 23, 25, (690, -730), (97, -40), (197, 124), breaker=True, target_slot='&"shell"', feedback='&"heavy"'),
        ]),
    ]
    for name, fields, moves in characters:
        fields.update(id=f'&"{name}"', display_name=name.upper(), color=palettes[name][0], energy=palettes[name][1])
        attacks = dict(zip(('light', 'heavy', 'uppercut', 'slam'), moves))
        if name == 'zero':
            attacks['ranged_heavy'] = attack('zero_scope', .24, .06, .32, 18, 21, (760, -320), (145, -93), (150, 75), breaker=True, delivery='&"rail"', projectile_speed='Vector2(1750, 0)', projectile_lifetime=.62, projectile_radius='Vector2(30, 20)', feedback='&"switch"')
            attacks['support_heavy'] = attack('zero_sync', .22, .12, .31, 16, 20, (540, -590), (89, -92), (235, 150), breaker=True, delivery='&"repair"', projectile_lifetime=1.1, feedback='&"halo"')
        resource(f'characters/{name}.tres', 'MechData', 'mech_data', fields, attacks)
    weapons = [
        ('phase_talon', 'PHASE TALON', 'TALON', 'shadow', 1.25, 'blink', attack('phase_cut', .23, .09, .31, 22, 23, (890, -435), (85, -82), (150, 132), breaker=True, delivery='&"blink"', travel_distance=270.0, hitstop=.075, feedback='&"phase"')),
        ('prism_emitter', 'PRISM EMITTER', 'PRISM', 'lumi', 2.35, 'field', attack('prism_zone', .24, .08, .34, 18, 21, (520, -650), (105, -95), (170, 170), breaker=True, delivery='&"field"', projectile_speed='Vector2(610, 0)', projectile_lifetime=2.8, projectile_radius='Vector2(88, 83)', piercing=True, feedback='&"prism"')),
        ('rail_lance', 'RAIL LANCE', 'RAIL', 'kai', 1.85, 'rail', attack('rail_shot', .62, .065, .52, 40, 34, (1570, -470), (165, -98), (170, 75), breaker=True, delivery='&"rail"', projectile_speed='Vector2(2800, 0)', projectile_lifetime=.82, projectile_radius='Vector2(38, 17)', piercing=True, hitstop=.10, hitstun=.36, feedback='&"rail"')),
        ('switch_driver', 'SWITCH DRIVER', 'DRIVER', 'zero', 1.05, 'adaptive', attack('drive_strike', .16, .17, .28, 22, 22, (920, -410), (119, -85), (208, 128), breaker=True, movement=730.0, feedback='&"switch"')),
    ]
    for name, title, short, donor, cooldown, action, move in weapons:
        moves = {'attack': move}
        if name == 'switch_driver':
            moves['up_attack'] = attack('drive_lift', .18, .12, .31, 21, 22, (270, -1320), (63, -147), (183, 230), breaker=True, feedback='&"switch"')
            moves['down_attack'] = attack('drive_guard', .23, .10, .32, 17, 23, (520, -700), (85, -40), (200, 145), breaker=True, target_slot='&"shell"', delivery='&"field"', projectile_speed='Vector2(420, 100)', projectile_lifetime=1.2, projectile_radius='Vector2(81, 65)', piercing=True, feedback='&"switch"')
        resource(f'modules/{name}.tres', 'ModuleData', 'module_data', dict(id=f'&"{name}"', display_name=title, short_name=short, donor=f'&"{donor}"', color=palettes[donor][0], energy=palettes[donor][1], cooldown=cooldown, action=f'&"{action}"'), moves)
    for name, title, short, donor, modifiers in [
        ('mirage_mantle', 'MIRAGE MANTLE', 'MIRAGE', 'shadow', dict(air_scale=1.19, resistance=.88, dodge_cooldown_scale=.82)),
        ('prism_shell', 'PRISM SHELL', 'PRISM', 'lumi', dict(acceleration_scale=.96, air_scale=1.08, resistance=1.06)),
        ('flux_frame', 'FLUX FRAME', 'FLUX', 'kai', dict(acceleration_scale=1.10, air_scale=1.19, resistance=.85)),
        ('adaptive_shell', 'ADAPTIVE SHELL', 'ADAPT', 'zero', dict(acceleration_scale=1.06, air_scale=1.06, resistance=1.0, dodge_cooldown_scale=.94)),
    ]:
        resource(f'modules/{name}.tres', 'ModuleData', 'module_data', dict(id=f'&"{name}"', display_name=title, short_name=short, slot='&"shell"', donor=f'&"{donor}"', color=palettes[donor][0], energy=palettes[donor][1], maximum=60.0, **modifiers))
    print('Authored four expansion chassis and eight transferable modules.')


if __name__ == '__main__':
    build()
