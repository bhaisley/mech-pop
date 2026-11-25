"""Build the four New Challengers kits and their interchangeable equipment."""
from create_data import attack, resource
from create_expansion_data import color


# Light, level breaker, rising breaker and slam. Each row specifies the timing,
# impact, launch and reach in simulation units, in that order.
pilots = {
    'rivet': ('SALVAGE RIGGER', 'Loose parts belong on a mech.', 'Reel loose gear closer with the Mag Fork. Start your catch from farther away.',
              'EB8238', '61F4E0', dict(height=168, width=88, mass=1.13, speed=725, pickup_reach=195), 'mag_fork', 'winch_pack', [
                  (.07,.07,.17,9,11,(380,-170),(91,-78),(151,85)),
                  (.19,.10,.28,19,24,(770,-330),(114,-78),(184,112)),
                  (.15,.09,.28,18,22,(210,-1110),(51,-131),(154,184)),
                  (.21,.11,.29,23,26,(540,-670),(92,-39),(192,120))]),
    'kite': ('AIR COURIER', 'See you on the way back.', 'Jump twice in midair. Line up both passes of the Gale Disc.',
             '25BCB0', 'FFE680', dict(height=163, width=66, mass=.76, speed=835, gravity=2140, air_acceleration=3850, jump_speed=1260, air_jump_speed=890, air_jumps=2), 'gale_disc', 'sail_frame', [
                 (.046,.066,.15,7,7,(300,-210),(83,-82),(137,78)),
                 (.15,.09,.24,17,18,(865,-405),(117,-86),(178,97)),
                 (.12,.08,.24,16,18,(210,-1190),(48,-132),(129,187)),
                 (.175,.10,.25,19,21,(630,-650),(87,-38),(169,110))]),
    'rook': ('COUNTER GUARD', 'Your move.', 'Raise the Gate Shield just before a frontal hit to answer with a bash. Stand your ground to resist launch.',
             'DCE5D0', 'FFC960', dict(height=194, width=102, mass=1.26, speed=655, acceleration=4700, gravity=2660, ground_brace=1.31), 'gate_shield', 'keystone_plate', [
                 (.09,.09,.21,11,11,(465,-200),(85,-92),(141,106)),
                 (.245,.115,.32,25,25,(1030,-430),(103,-86),(178,138)),
                 (.20,.105,.31,23,23,(290,-1200),(53,-145),(160,202)),
                 (.25,.12,.34,26,28,(720,-735),(76,-38),(216,136))]),
    'coda': ('ECHO DRUMMER', 'Wait for the second beat.', 'Strike the Echo Bell, then herd rivals back into its second beat. Hold down in the air for a steep descent.',
             'A54C91', 'FFD176', dict(height=173, width=80, mass=.96, speed=755, acceleration=6550, jump_speed=1430, fast_fall=2.7), 'echo_bell', 'resonance_shell', [
                 (.055,.085,.175,8,9,(355,-245),(95,-84),(166,82)),
                 (.205,.115,.27,20,22,(820,-475),(121,-85),(207,114)),
                 (.155,.10,.285,19,21,(240,-1230),(65,-132),(169,190)),
                 (.20,.125,.285,23,24,(650,-695),(98,-41),(205,126))]),
}


def build():
    for name, (role, quote, description, armor, glow, chassis, weapon, shell, strikes) in pilots.items():
        colors = dict(color=color(armor), energy=color(glow))
        moves = {}
        for kind, values in zip(('light', 'heavy', 'uppercut', 'slam'), strikes):
            moves[kind] = attack(f'{name}_{kind}', *values, breaker=kind != 'light',
                                 target_slot='&"shell"' if kind == 'slam' else '&"weapon_arm"',
                                 hitstop=.04 if kind == 'light' else .075,
                                 feedback='&"light"' if kind == 'light' else '&"heavy"')
        resource(f'characters/{name}.tres', 'MechData', 'mech_data', dict(
            id=f'&"{name}"', display_name=name.upper(), role=role, quote=quote, description=description,
            native_weapon=f'&"{weapon}"', native_shell=f'&"{shell}"', face_region='Rect2(125, 94, 510, 510)', **colors, **chassis), moves)

    def equipment(name, donor, short, slot='weapon_arm', moves=None, **fields):
        pilot = pilots[donor]
        resource(f'modules/{name}.tres', 'ModuleData', 'module_data', dict(
            id=f'&"{name}"', display_name=name.replace('_', ' ').upper(), short_name=short,
            slot=f'&"{slot}"', donor=f'&"{donor}"', color=color(pilot[3]), energy=color(pilot[4]), **fields), moves)

    equipment('mag_fork','rivet','MAG FORK', cooldown=1.45, action='&"magnet"', moves={'attack':
        attack('mag_tug',.17,.09,.29,12,17,(-440,-220),(112,-82),(192,116),delivery='&"magnet"',feedback='&"chassis/rivet_special"')})
    equipment('gale_disc','kite','DISC', cooldown=1.55, action='&"disc"', moves={'attack':
        attack('gale_return',.16,.08,.23,12,10,(390,-235),(108,-86),(120,72),delivery='&"disc"',projectile_speed='Vector2(1040, 0)',phase_delay=.40,projectile_lifetime=1.48,projectile_radius='Vector2(44, 29)',piercing=True,feedback='&"chassis/kite_special"')})
    equipment('gate_shield','rook','GATE', cooldown=1.48, action='&"parry"', moves={
        'attack': attack('gate_guard',.095,.235,.34,0,0,(0,0),(81,-92),(130,158),delivery='&"parry"',feedback='&"chassis/rook_special"'),
        'counter_attack': attack('gate_bash',.045,.11,.32,27,27,(1080,-455),(115,-89),(218,146),breaker=True,movement=385,hitstop=.09,feedback='&"heavy"')})
    equipment('echo_bell','coda','BELL', cooldown=1.86, action='&"echo"', moves={'attack':
        attack('echo_stamp',.205,.095,.27,13,15,(305,-170),(157,-94),(212,141),delivery='&"echo"',phase_delay=.48,projectile_lifetime=.64,projectile_radius='Vector2(106, 70)',piercing=True,breaker=True,feedback='&"chassis/coda_special"')})
    equipment('winch_pack','rivet','WINCH','shell',maximum=61,acceleration_scale=1.09,resistance=1.06)
    equipment('sail_frame','kite','SAIL','shell',maximum=49,air_scale=1.35,resistance=.91)
    equipment('keystone_plate','rook','KEYSTONE','shell',maximum=67,acceleration_scale=.91,resistance=1.18)
    equipment('resonance_shell','coda','RESONATOR','shell',maximum=55,air_scale=1.06,dodge_cooldown_scale=.85)


if __name__ == '__main__':
    build()
