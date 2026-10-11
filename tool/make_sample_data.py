#!/usr/bin/env python3
"""Builds a realistic Apple-Watch-style test dataset for Wateen.

46 days (27 Aug – 11 Oct 2026, Kuwait time) for a 35-year-old man with an
office job, gym three times a week, weekly football and runs. The story:

  27 Aug – 6 Sep   normal routine
  7 – 15 Sep       training overload + work deadline, late caffeine, short sleep
  16 – 19 Sep      a cold: higher resting HR, temperature and breathing, low HRV
  20 – 26 Sep      recovery, good sleep; the watch charged overnight 23→24 Sep
  27 Sep – 2 Oct   business trip to London (2 h behind Kuwait), lots of walking
  3 – 11 Oct       back home, steady habits, 10 km race on Friday 9 Oct

Physiology responds to behaviour, training load, sleep and illness, and the
daily journal answers match what happened, so every screen of the app has
something real to show. Output: samples/wateen-sample-data.json

Usage: python3 tool/make_sample_data.py [output.json]
"""
import json
import math
import os
import random
import sys
from datetime import date, datetime, timedelta

SEED = 20261011
R = random.Random(SEED)
EPOCH = datetime(1970, 1, 1)
KW = 3      # Kuwait, UTC+3
LON = 1     # London in BST, UTC+1

FIRST_WAKE = date(2026, 8, 27)
LAST_WAKE = date(2026, 10, 11)
END_LOCAL = datetime(2026, 10, 11, 7, 40)       # Kuwait time: the file ends here

OVERLOAD = (date(2026, 9, 7), date(2026, 9, 15))
DEADLINE = (date(2026, 9, 10), date(2026, 9, 15))
SICK = {date(2026, 9, 16): 1.0, date(2026, 9, 17): 0.85, date(2026, 9, 18): 0.55, date(2026, 9, 19): 0.25}
RECOVERY = (date(2026, 9, 20), date(2026, 9, 26))
TRAVEL = (date(2026, 9, 27), date(2026, 10, 2))
HOME = (date(2026, 10, 3), date(2026, 10, 11))
RACE = date(2026, 10, 9)
MISSING_NIGHT_WAKE = date(2026, 9, 24)          # watch on the charger that night
WATCH_OFF = (datetime(2026, 10, 5, 13, 0), datetime(2026, 10, 5, 16, 10))
FASTING = {date(2026, 9, 2), date(2026, 9, 7), date(2026, 9, 21), date(2026, 10, 5)}
JOURNAL_SKIPPED = {date(2026, 8, 30), date(2026, 9, 13), date(2026, 9, 18), date(2026, 10, 4)}

WATCH = 'Apple Watch'
PHONE = 'iPhone'


def between(d, span):
    return span[0] <= d <= span[1]


def ts(local, offset):
    """Local wall-clock time at UTC+offset -> epoch seconds."""
    return int(round((local - timedelta(hours=offset) - EPOCH).total_seconds()))


def kw_local(epoch):
    return EPOCH + timedelta(seconds=epoch, hours=KW)


def gauss(sd=1.0):
    return R.gauss(0.0, sd)


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def is_weekend(d):
    return d.isoweekday() in (5, 6)          # Friday, Saturday


def is_workday(d):
    return not is_weekend(d)


def tz_of_day(d):
    """Where the person is during day d (after the morning)."""
    return LON if TRAVEL[0] <= d < TRAVEL[1] else KW


# ----------------------------------------------------------------- plans

class Workout:
    def __init__(self, kind, start, minutes, offset):
        self.kind = kind            # profile name
        self.start = start          # local datetime
        self.minutes = minutes
        self.offset = offset

    @property
    def end(self):
        return self.start + timedelta(minutes=self.minutes)


HEALTH_TYPE = {
    'strength': 'TRADITIONAL_STRENGTH_TRAINING',
    'run': 'RUNNING',
    'easy_run': 'RUNNING',
    'intervals': 'RUNNING',
    'race': 'RUNNING',
    'long_run': 'RUNNING',
    'football': 'SOCCER',
    'walk': 'WALKING',
    'ride': 'BIKING',
    'hiit': 'HIGH_INTENSITY_INTERVAL_TRAINING',
    'yoga': 'YOGA',
}

# (relative load per minute) used for the latent training-load model
LOAD_PER_MIN = {
    'strength': 0.9, 'run': 1.5, 'easy_run': 1.0, 'intervals': 2.0, 'race': 2.6, 'long_run': 1.5,
    'football': 1.8, 'walk': 0.35, 'ride': 1.2, 'hiit': 1.9, 'yoga': 0.2,
}


def at(d, h, m=0):
    return datetime(d.year, d.month, d.day) + timedelta(hours=h, minutes=m)


def plan_workouts(d):
    off = tz_of_day(d)
    wd = d.isoweekday()          # Mon=1 .. Sun=7
    w = []
    if d in SICK:
        return w
    if between(d, RECOVERY):
        table = {
            date(2026, 9, 20): [('walk', 17, 30, 25)],
            date(2026, 9, 21): [('walk', 18, 0, 30)],
            date(2026, 9, 22): [('yoga', 19, 0, 30)],
            date(2026, 9, 23): [('walk', 18, 30, 40)],
            date(2026, 9, 24): [('easy_run', 19, 30, 30)],
            date(2026, 9, 25): [('walk', 18, 0, 45)],
            date(2026, 9, 26): [('strength', 18, 0, 45)],
        }
        return [Workout(k, at(d, h, m), mins, off) for k, h, m, mins in table.get(d, [])]
    if between(d, TRAVEL):
        table = {
            date(2026, 9, 29): [('strength', 7, 0, 45)],    # hotel gym
            date(2026, 10, 1): [('run', 7, 15, 35)],        # Hyde Park
        }
        return [Workout(k, at(d, h, m), mins, off) for k, h, m, mins in table.get(d, [])]
    if d == RACE:
        return [Workout('race', at(d, 6, 30), 52, off)]
    if d == date(2026, 10, 10):
        return [Workout('walk', at(d, 17, 30), 35, off)]
    if d == date(2026, 10, 3):
        return [Workout('walk', at(d, 18, 0), 45, off)]
    if d == date(2026, 10, 11):
        return []
    overload = between(d, OVERLOAD)
    jitter = R.randint(-10, 10)
    if wd == 7:   # Sunday
        w.append(Workout('strength', at(d, 19, 0) + timedelta(minutes=jitter), 75 if overload else 60, off))
    elif wd == 1:  # Monday
        w.append(Workout('run', at(d, 20, 30) + timedelta(minutes=jitter), 45 if overload else 40, off))
    elif wd == 2:  # Tuesday
        if overload:
            w.append(Workout('easy_run', at(d, 5, 55), 30, off))
        w.append(Workout('strength', at(d, 19, 0) + timedelta(minutes=jitter), 75 if overload else 60, off))
    elif wd == 3:  # Wednesday
        if overload:
            w.append(Workout('hiit', at(d, 19, 30), 35, off))
        elif d == date(2026, 10, 7):
            w.append(Workout('intervals', at(d, 19, 45), 42, off))
        else:
            w.append(Workout('walk', at(d, 20, 0) + timedelta(minutes=jitter), 40, off))
    elif wd == 4:  # Thursday
        if overload:
            w.append(Workout('easy_run', at(d, 5, 55), 30, off))
        w.append(Workout('strength', at(d, 18, 30) + timedelta(minutes=jitter), 70 if overload else 55, off))
    elif wd == 5:  # Friday
        w.append(Workout('football', at(d, 21, 15), 80, off))
    elif wd == 6:  # Saturday
        if overload:
            w.append(Workout('long_run', at(d, 6, 30), 70, off))
        elif d.isocalendar()[1] % 2 == 0:
            w.append(Workout('ride', at(d, 6, 45), 80, off))
        else:
            w.append(Workout('walk', at(d, 18, 0) + timedelta(minutes=jitter), 50, off))
    return w


def p(prob):
    return R.random() < prob


def plan_behaviour(d, workouts):
    overload = between(d, OVERLOAD)
    deadline = between(d, DEADLINE)
    sick = d in SICK
    recovery = between(d, RECOVERY)
    travel = between(d, TRAVEL)
    home = between(d, HOME)
    weekend_night = d.isoweekday() in (4, 5)     # Thursday and Friday nights out
    b = {}
    b['caffeine_late'] = p(0.75 if overload else 0.1 if (sick or recovery) else 0.4 if travel else 0.15 if home else 0.3)
    b['energy_drink'] = p(0.35 if deadline else 0.03)
    b['late_meal'] = p(0.05 if sick else 0.55 if overload else 0.5 if travel else 0.15 if recovery
                       else 0.2 if home else 0.35 if weekend_night else 0.3)
    b['screen_bed'] = p(0.6 if overload else 0.1 if recovery else 0.2 if home else 0.1 if sick else 0.45)
    b['hydrated'] = p(0.3 if overload else 0.5 if sick else 0.8 if recovery else 0.75 if home else 0.55)
    if travel:
        b['work_stress'] = p(0.4)
    elif is_workday(d) and not sick:
        b['work_stress'] = p(0.9 if deadline else 0.25 if home else 0.3)
    else:
        b['work_stress'] = p(0.05)
    b['reading_bed'] = p(0.6 if recovery else 0.5 if home else 0.15 if overload else 0.25)
    b['stretching'] = p(0.7 if recovery else 0.45 if home else 0.15 if overload else 0.2)
    if sick or travel:
        b['smoking'] = False
    elif weekend_night:
        b['smoking'] = p(0.15 if home else 0.45)
    else:
        b['smoking'] = p(0.04)
    b['fasting'] = d in FASTING
    b['late_workout'] = any(w.start.hour >= 21 for w in workouts)
    b['travel'] = travel
    b['sick'] = sick
    b['sauna'] = p(0.3 if travel else 0.06)
    b['outdoor_light'] = p(0.0 if sick else 0.85 if travel else 0.6 if home else 0.3)
    b['nap'] = False             # filled after naps are planned
    return b


class Night:
    """The night that starts on the evening of day `d` and ends on the next morning."""

    def __init__(self, d, bed, wake, offset):
        self.d = d
        self.bed = bed              # local datetime at offset
        self.wake = wake
        self.offset = offset
        self.segments = []          # (start, end, stage) local
        self.sleep_start = bed
        self.asleep_min = 0.0
        self.deep_min = 0.0


def plan_night(d, beh, workouts):
    wake_day = d + timedelta(days=1)
    if TRAVEL[0] <= d < TRAVEL[1]:
        offset = LON
    else:
        offset = KW
    # Defaults: work nights vs weekend nights.
    if is_weekend(wake_day) or wake_day.isoweekday() == 5:
        bed = at(wake_day, 0, 45) + timedelta(minutes=gauss(25))
        wake = at(wake_day, 8, 45) + timedelta(minutes=gauss(35))
    else:
        bed = at(d, 23, 5) + timedelta(minutes=gauss(18))
        wake = at(wake_day, 6, 15) + timedelta(minutes=gauss(6))
    if beh.get('screen_bed'):
        bed += timedelta(minutes=25)
    if beh.get('caffeine_late') or beh.get('energy_drink'):
        bed += timedelta(minutes=15)
    if beh.get('smoking'):
        bed += timedelta(minutes=40)
    for w in workouts:
        if w.start.hour >= 21:
            bed = max(bed, w.end + timedelta(minutes=95))
    if between(d, DEADLINE) and is_workday(wake_day):
        bed += timedelta(minutes=30)
    if between(wake_day, OVERLOAD) and wake_day.isoweekday() in (2, 4):
        wake = at(wake_day, 5, 35) + timedelta(minutes=gauss(4))     # early run
    if wake_day == date(2026, 9, 12) or wake_day == date(2026, 9, 5):
        wake = at(wake_day, 6, 25)                                    # long run / ride morning
    if wake_day in SICK or d in SICK:
        bed = at(d, 22, 30) + timedelta(minutes=gauss(10))
        wake = at(wake_day, 8, 30) + timedelta(minutes=gauss(15))
    if between(wake_day, RECOVERY) and wake_day not in SICK:
        if is_workday(wake_day):
            bed = at(d, 22, 50) + timedelta(minutes=gauss(12))
            wake = at(wake_day, 6, 20) + timedelta(minutes=gauss(5))
        else:
            bed = at(d, 23, 45) + timedelta(minutes=gauss(10))
            wake = at(wake_day, 8, 30) + timedelta(minutes=gauss(15))
    if between(wake_day, HOME) and is_workday(wake_day) and wake_day not in (date(2026, 10, 3),):
        bed = at(d, 23, 0) + timedelta(minutes=gauss(12)) + timedelta(minutes=20 if beh.get('screen_bed') else 0)
        wake = at(wake_day, 6, 15) + timedelta(minutes=gauss(5))
    if TRAVEL[0] <= d < TRAVEL[1]:
        # London nights (local London time).
        bed = at(d, 23, 30) + timedelta(minutes=gauss(15) + (25 if beh.get('late_meal') else 0))
        wake = at(wake_day, 7, 15) + timedelta(minutes=gauss(10))
        if d == TRAVEL[0]:
            bed = at(d, 23, 50)
            wake = at(wake_day, 5, 50)              # body still on Kuwait time
    if d == TRAVEL[1]:
        bed = at(wake_day, 0, 40)                    # landed in Kuwait 22:00
        wake = at(wake_day, 8, 50)
    if wake_day == RACE:
        bed = at(d, 22, 15)
        wake = at(wake_day, 5, 10)
    if wake_day == date(2026, 10, 11):
        bed = at(d, 23, 5)
        wake = at(wake_day, 6, 22)
    return Night(d, bed, wake, offset)


def build_stages(n, beh, sick_level, readiness_hint, rng=R):
    """Fills n.segments with a realistic hypnogram (local times)."""
    latency = 10 + rng.randint(0, 12)
    if beh.get('caffeine_late') or beh.get('energy_drink'):
        latency += 22
    if beh.get('reading_bed'):
        latency = max(4, latency - 8)
    if n.d == TRAVEL[0]:
        latency += 20
    t = n.bed + timedelta(minutes=latency)
    n.segments.append((n.bed, t, 'awake'))
    n.sleep_start = t
    total_span = (n.wake - t).total_seconds() / 60
    cycle = 0
    deep_factor = 1.0
    if beh.get('caffeine_late') or beh.get('energy_drink'):
        deep_factor *= 0.72
    if beh.get('late_meal'):
        deep_factor *= 0.88
    if beh.get('smoking'):
        deep_factor *= 0.85
    if sick_level > 0:
        deep_factor *= 1.0 - 0.25 * sick_level
    rem_factor = 1.0 - 0.35 * sick_level
    if n.d == TRAVEL[0]:
        rem_factor *= 0.8
    wake_prob = 0.35 + 0.45 * sick_level + (0.25 if n.d == TRAVEL[0] else 0)
    asleep = 0.0
    deep_total = 0.0
    while True:
        remaining = (n.wake - t).total_seconds() / 60
        if remaining < 8:
            break
        length = 90 + gauss(9)
        if cycle == 0:
            deep_share, rem_share = 0.30, 0.09
        elif cycle == 1:
            deep_share, rem_share = 0.22, 0.17
        elif cycle == 2:
            deep_share, rem_share = 0.12, 0.25
        else:
            deep_share, rem_share = 0.04, 0.32
        deep = length * deep_share * deep_factor
        rem = length * rem_share * rem_factor
        core = length - deep - rem
        scale = min(1.0, remaining / length)
        for stage, minutes in (('light', core * 0.5), ('deep', deep), ('light', core * 0.5), ('rem', rem)):
            minutes *= scale
            if minutes < 0.6:
                continue
            e = t + timedelta(minutes=minutes)
            if e > n.wake:
                e = n.wake
            if e <= t:
                continue
            n.segments.append((t, e, stage))
            asleep += (e - t).total_seconds() / 60
            if stage == 'deep':
                deep_total += (e - t).total_seconds() / 60
            t = e
        if t < n.wake and rng.random() < wake_prob:
            aw = 2 + rng.randint(0, 6) + (8 * sick_level if rng.random() < 0.5 else 0)
            e = min(n.wake, t + timedelta(minutes=aw))
            n.segments.append((t, e, 'awake'))
            t = e
        cycle += 1
        if cycle > 12:
            break
    n.asleep_min = asleep
    n.deep_min = deep_total
    # A short awake stretch at the end, as the watch usually records.
    if t < n.wake:
        n.segments.append((t, n.wake, 'awake'))


# ------------------------------------------------------------------ main

def main(out_path):
    days = []
    d = FIRST_WAKE - timedelta(days=1)
    while d <= LAST_WAKE:
        days.append(d)
        d += timedelta(days=1)

    workouts = {d: plan_workouts(d) for d in days}
    behaviour = {d: plan_behaviour(d, workouts[d]) for d in days}
    nights = {d: plan_night(d, behaviour[d], workouts[d]) for d in days if d < LAST_WAKE}

    # Naps (local, by day).
    naps = {}
    for d in days:
        if d in SICK and d != date(2026, 9, 19):
            naps[d] = (at(d, 13, 40), 55 + R.randint(0, 20))
        elif d == TRAVEL[0]:
            naps[d] = (at(d, 16, 10), 40)
        elif d.isoweekday() == 5 and d != RACE and not between(d, TRAVEL) and R.random() < 0.7:
            naps[d] = (at(d, 15, 25), 25 + R.randint(0, 15))
        elif d == RACE:
            naps[d] = (at(d, 14, 0), 45)
    for d in days:
        behaviour[d]['nap'] = d in naps

    # Sleep stages need a sick level for the night's wake day.
    for d, n in nights.items():
        wake_day = d + timedelta(days=1)
        build_stages(n, behaviour[d], SICK.get(wake_day, 0.0), 0.0)

    # Latent training load (acute vs chronic).
    load = {}
    for d in days:
        L = sum(LOAD_PER_MIN[w.kind] * w.minutes for w in workouts[d])
        L += 12 if between(d, TRAVEL) else 0                 # walking around the city
        load[d] = L
    typical = 70.0
    acute = typical
    chronic = typical
    acwr = {}
    for d in days:
        acwr[d] = acute / max(chronic, 1.0)
        acute = acute + (load[d] - acute) / 7.0
        chronic = chronic + (load[d] - chronic) / 28.0

    # Readiness for each wake day.
    effects = {
        'caffeine_late': -0.45, 'energy_drink': -0.35, 'late_meal': -0.5, 'screen_bed': -0.15,
        'hydrated': 0.25, 'work_stress': -0.35, 'reading_bed': 0.12, 'stretching': 0.18, 'smoking': -0.65,
        'late_workout': -0.25, 'sauna': 0.12, 'outdoor_light': 0.08,
    }
    illness = {date(2026, 9, 16): -2.4, date(2026, 9, 17): -2.0, date(2026, 9, 18): -1.8, date(2026, 9, 19): -1.4,
               date(2026, 9, 20): -0.6}
    readiness = {}
    z_prev = 0.0
    for d in days:
        if d == days[0]:
            continue
        prev = d - timedelta(days=1)
        n = nights.get(prev)
        z = 0.30 * z_prev
        for k, v in effects.items():
            if behaviour[prev].get(k):
                z += v
        if prev == TRAVEL[0] or prev == TRAVEL[1]:
            z -= 0.6                                          # flight days
        z += -1.4 * max(0.0, acwr[d] - 1.15) - 0.10 * (load[prev] / typical - 1.0)
        if n is not None:
            # Extra sleep while ill or catching up helps only a little.
            cap = 0.1 if (d in SICK or d == date(2026, 9, 20)) else 0.6
            z += clamp(0.45 * (n.asleep_min / 60.0 - 7.0), -1.2, cap)
        z += illness.get(d, 0.0)
        if date(2026, 9, 22) <= d <= date(2026, 9, 26):
            z += 0.25
        if between(d, HOME):
            z += 0.15
        if d == date(2026, 10, 10):
            z -= 0.5                                          # day after the race
        z += gauss(0.45)
        readiness[d] = z
        z_prev = z

    data = {
        'format': 'wateen-raw',
        'version': 1,
        'alignToToday': True,
        'description': 'Wateen sample data: 46 days of simulated Apple Watch records (Kuwait time).',
        'hrvType': 'sdnn',
        'heartRate': [], 'hrv': [], 'restingHr': [], 'respiratoryRate': [], 'spo2': [], 'skinTemp': [],
        'sleep': [], 'workouts': [], 'steps': [], 'dailySteps': {}, 'activeEnergy': {}, 'journal': {},
    }
    end_epoch = ts(END_LOCAL, KW)

    def add_hr(local, offset, bpm):
        t = ts(local, offset)
        if t > end_epoch:
            return
        lk = kw_local(t)
        if WATCH_OFF[0] <= lk < WATCH_OFF[1]:
            return
        data['heartRate'].append([t, int(round(bpm))])

    # ---- nights
    for d, n in nights.items():
        wake_day = d + timedelta(days=1)
        z = readiness[wake_day]
        sick = SICK.get(wake_day, 0.0)
        beh = behaviour[d]
        off = n.offset
        # Phone "in bed" (sleep schedule) is recorded even without the watch.
        data['sleep'].append([ts(n.bed - timedelta(minutes=6), off), ts(n.wake + timedelta(minutes=3), off), 'inBed', PHONE])
        if wake_day == MISSING_NIGHT_WAKE:
            continue
        for s, e, stage in n.segments:
            data['sleep'].append([ts(s, off), ts(e, off), stage, WATCH])
        hr_base = 53.0 - 2.0 * z + 6.5 * sick + (2.5 if beh.get('late_meal') else 0) + (3.0 if beh.get('smoking') else 0)
        hr_base += 1.0 if beh.get('caffeine_late') else 0
        t = n.sleep_start
        seg_i = 0
        segs = n.segments
        while t < n.wake:
            while seg_i < len(segs) - 1 and segs[seg_i][1] <= t:
                seg_i += 1
            stage = segs[seg_i][2]
            frac = (t - n.sleep_start).total_seconds() / max(1.0, (n.wake - n.sleep_start).total_seconds())
            bpm = hr_base + gauss(1.6) + 3.0 * (1 - frac) * 0.6     # slightly higher early in the night
            if stage == 'rem':
                bpm += 4
            elif stage == 'deep':
                bpm -= 2
            elif stage == 'awake':
                bpm += 9
            add_hr(t, off, bpm)
            t += timedelta(minutes=4 + R.random() * 3)
        span = (n.wake - n.sleep_start).total_seconds() / 60
        hrv_night = 48.0 * math.exp(0.16 * z) * (1 - 0.05 * sick)
        for i in range(3 + R.randint(0, 2)):
            tt = n.sleep_start + timedelta(minutes=span * (0.12 + 0.2 * i) + gauss(6))
            if tt < n.wake:
                data['hrv'].append([ts(tt, off), round(hrv_night * math.exp(gauss(0.07)), 1)])
        for i in range(4):
            tt = n.sleep_start + timedelta(minutes=span * (0.15 + 0.2 * i))
            rr = 14.3 - 0.12 * z + 1.7 * sick + gauss(0.18)
            data['respiratoryRate'].append([ts(tt, off), round(rr, 1)])
        for i in range(6):
            tt = n.sleep_start + timedelta(minutes=span * (0.08 + 0.15 * i) + gauss(5))
            o2 = clamp(96.6 - 1.3 * sick + gauss(0.6), 92.0, 99.6)
            data['spo2'].append([ts(tt, off), round(o2, 1)])
        temp = 35.62 + 0.68 * sick + gauss(0.07)
        data['skinTemp'].append([ts(n.wake, off), round(temp, 2)])

    # ---- days
    for d in days:
        if d < FIRST_WAKE:
            continue
        prev_night = nights.get(d - timedelta(days=1))
        tonight = nights.get(d)
        z = readiness[d]
        sick = SICK.get(d, 0.0)
        beh = behaviour[d]
        off_morning = prev_night.offset if prev_night else KW
        wake = prev_night.wake if prev_night else at(d, 6, 30)
        # The day ends at tonight's bedtime (or at the end of the file).
        if tonight is not None:
            day_end_epoch = ts(tonight.bed, tonight.offset)
        else:
            day_end_epoch = end_epoch
        day_off = tz_of_day(d)
        flight = None
        if d == TRAVEL[0]:
            flight = (at(d, 8, 30), KW, at(d, 13, 0), LON)       # leave Kuwait, land London
        if d == TRAVEL[1]:
            flight = (at(d, 14, 0), LON, at(d, 22, 0), KW)       # leave London, land Kuwait

        def local_of(epoch, off):
            return EPOCH + timedelta(seconds=epoch, hours=off)

        # Walking bouts (local time of the day's place).
        bouts = []
        if not sick:
            bouts.append((at(d, 7, 25), 6))          # to the car / office
            bouts.append((at(d, 12, 45), 8))
            bouts.append((at(d, 16, 5), 6))
            for _ in range(R.randint(2, 5)):
                bouts.append((at(d, R.randint(9, 21), R.randint(0, 59)), R.randint(4, 14)))
            if between(d, TRAVEL) and d not in (TRAVEL[0], TRAVEL[1]):
                for h in (9, 12, 14, 17, 19):
                    bouts.append((at(d, h, R.randint(0, 40)), R.randint(18, 40)))
        else:
            bouts.append((at(d, 12, 0), 3))
        wk = workouts[d]

        def in_workout(local):
            for w in wk:
                if w.start <= local < w.end:
                    return w
            return None

        def in_bout(local):
            for s, m in bouts:
                if s <= local < s + timedelta(minutes=m):
                    return True
            return False

        nap = naps.get(d)
        nap_window = (nap[0], nap[0] + timedelta(minutes=nap[1])) if nap else None

        # Background heart rate from wake to bedtime.
        steps_by_chunk = {}
        t_epoch = ts(wake, off_morning) + 60
        while t_epoch < day_end_epoch and t_epoch <= end_epoch:
            if flight is not None and ts(flight[0], flight[1]) <= t_epoch < ts(flight[2], flight[3]):
                off = None
            elif flight is not None and t_epoch >= ts(flight[2], flight[3]):
                off = flight[3]
            elif flight is not None:
                off = flight[1]
            else:
                off = day_off if day_off == off_morning else (day_off if t_epoch > ts(at(d, 10, 0), day_off) else off_morning)
            if WATCH_OFF[0] <= kw_local(t_epoch) < WATCH_OFF[1]:
                t_epoch += 300
                continue
            loc = local_of(t_epoch, off if off is not None else KW)
            w = in_workout(loc) if off is not None else None
            if w is not None:
                t_epoch = ts(w.end, w.offset)
                continue
            if nap_window and nap_window[0] <= loc < nap_window[1]:
                bpm = 57 - 1.5 * z + 6 * sick + gauss(2)
                step = 300
            elif in_bout(loc):
                bpm = 101 + gauss(5) + 4 * sick
                step = 60 + R.randint(0, 60)
            else:
                bpm = 69 - 1.0 * z + 5 * sick + gauss(4)
                hour = loc.hour
                if beh.get('work_stress') and 9 <= hour < 16 and is_workday(d) and off is not None:
                    bpm += 10 + (8 if R.random() < 0.12 else 0)
                if (beh.get('caffeine_late') or beh.get('energy_drink')) and 14 <= hour < 20:
                    bpm += 3
                if beh.get('fasting') and 13 <= hour < 17:
                    bpm -= 3
                if off is None:
                    bpm += 4                              # on the plane
                step = 270 + R.randint(0, 150)
            if R.random() < 0.06:
                step += 600                               # occasional gap
            add_hr(loc, off if off is not None else KW, bpm)
            # Steps for this sample's chunk.
            ck = (t_epoch // 600) * 600
            if in_bout(loc):
                steps_by_chunk[ck] = steps_by_chunk.get(ck, 0) + (step / 60.0) * (98 + R.randint(-10, 12))
            elif not (nap_window and nap_window[0] <= loc < nap_window[1]):
                steps_by_chunk[ck] = steps_by_chunk.get(ck, 0) + R.randint(0, 9 if sick else 40)
            t_epoch += step

        # Workouts.
        kcal_total = 0.0
        for w in wk:
            emit_workout(data, w, z, add_hr, steps_by_chunk)
            kcal_total += workout_kcal(w)
        # Naps as sleep sessions.
        if nap:
            s, mins = nap
            data['sleep'].append([ts(s, day_off), ts(s + timedelta(minutes=mins), day_off), 'light', WATCH])

        # Step samples (10-minute chunks) and the daily totals (Kuwait calendar day).
        total = 0
        for ck in sorted(steps_by_chunk):
            c = int(round(steps_by_chunk[ck]))
            if c <= 0 or ck > end_epoch:
                continue
            data['steps'].append([ck, ck + 600, c])
            total += c
        key = d.isoformat()
        if total > 0:
            data['dailySteps'][key] = total
            data['activeEnergy'][key] = int(round(230 + total * 0.038 + kcal_total))

        # Resting heart rate (one value a day, as the Health app records it).
        if prev_night is not None and d != LAST_WAKE:
            rhr = 58.0 - 1.6 * z + 6 * sick + gauss(0.8)
            data['restingHr'].append([ts(at(d, 20, 30), day_off), int(round(rhr))])
        # A daytime HRV reading.
        if d != LAST_WAKE and not (WATCH_OFF[0].date() == d):
            hrv_day = 0.8 * 48.0 * math.exp(0.16 * z) * math.exp(gauss(0.12))
            data['hrv'].append([ts(at(d, 15, R.randint(0, 50)), day_off), round(hrv_day, 1)])

        # Journal (the day is answered the next morning; today has none yet).
        if d != LAST_WAKE and d not in JOURNAL_SKIPPED:
            data['journal'][key] = {k: bool(v) for k, v in beh.items()}

    for k in ('heartRate', 'hrv', 'restingHr', 'respiratoryRate', 'spo2', 'skinTemp', 'steps'):
        data[k].sort(key=lambda r: r[0])
    data['sleep'].sort(key=lambda r: (r[0], r[1]))
    data['workouts'].sort(key=lambda w: w['start'])

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print(f'wrote {out_path}: {os.path.getsize(out_path) / 1024:.0f} KB, '
          f'{len(data["heartRate"])} heart-rate samples, {len(data["sleep"])} sleep segments, '
          f'{len(data["workouts"])} workouts, {len(data["journal"])} journal days')
    return data


def workout_kcal(w):
    per_min = {'strength': 7, 'run': 12, 'easy_run': 10, 'intervals': 13, 'race': 15, 'long_run': 12,
               'football': 11, 'walk': 5, 'ride': 10, 'hiit': 12, 'yoga': 3}[w.kind]
    return w.minutes * per_min


def emit_workout(data, w, z, add_hr, steps_by_chunk):
    """Heart rate every 10 s, steps and the workout record."""
    total = w.minutes * 60
    fresh = 1.0 + 0.012 * z                       # better recovered -> slightly lower HR at the same effort
    t = 0
    peak_phase = R.random() * 6.28
    while t < total:
        x = t / total
        local = w.start + timedelta(seconds=t)
        k = w.kind
        if k == 'strength':
            in_set = (t // 60) % 3 == 0
            bpm = (142 if in_set else 112) + 6 * math.sin(t / 37.0) + gauss(3)
        elif k in ('run', 'long_run'):
            bpm = 100 + 55 * min(1.0, x / 0.12) + 9 * x if x < 0.9 else 160 - 260 * (x - 0.9)
            bpm += gauss(2)
        elif k == 'easy_run':
            bpm = 100 + 40 * min(1.0, x / 0.15) + gauss(2)
        elif k == 'intervals':
            mins = t / 60
            if mins < 8:
                bpm = 105 + 4 * mins
            elif mins < 8 + 6 * 5:
                in_rep = ((mins - 8) % 5) < 3
                bpm = (174 if in_rep else 138) + gauss(2.5)
            else:
                bpm = 140 - 3 * (mins - 38)
        elif k == 'race':
            bpm = 120 + 52 * min(1.0, x / 0.06) + 12 * x + (6 if x > 0.95 else 0) + gauss(1.8)
        elif k == 'football':
            peak_phase += R.uniform(-0.6, 0.6)
            bpm = 150 + 26 * math.sin(peak_phase) + gauss(5)
            if x < 0.06:
                bpm = 110 + 600 * x
        elif k == 'walk':
            bpm = 104 + gauss(4)
        elif k == 'ride':
            bpm = 138 + 8 * math.sin(t / 300.0) + gauss(3)
        elif k == 'hiit':
            on = (t // 30) % 2 == 0
            bpm = (168 if on else 146) + gauss(3) if x > 0.12 else 110 + 300 * x
        elif k == 'yoga':
            bpm = 86 + gauss(3)
        else:
            bpm = 120 + gauss(5)
        bpm = clamp(bpm / fresh, 70, 190)
        add_hr(local, w.offset, bpm)
        ck = (ts(local, w.offset) // 600) * 600
        spm = {'run': 162, 'long_run': 160, 'easy_run': 156, 'intervals': 165, 'race': 172, 'football': 105,
               'walk': 108, 'hiit': 60, 'strength': 8, 'ride': 0, 'yoga': 0}[k]
        steps_by_chunk[ck] = steps_by_chunk.get(ck, 0) + spm * 10 / 60.0
        t += 10
    rec = {
        'start': ts(w.start, w.offset),
        'end': ts(w.end, w.offset),
        'type': HEALTH_TYPE[w.kind],
        'kcal': workout_kcal(w),
    }
    pace = {'run': 5.75, 'long_run': 6.0, 'easy_run': 6.4, 'intervals': 5.4, 'race': 4.95, 'walk': 11.5}
    if w.kind in pace:
        rec['distance'] = int(round(w.minutes / pace[w.kind] * 1000))
    if w.kind == 'ride':
        rec['distance'] = int(round(w.minutes / 60 * 26 * 1000))
    data['workouts'].append(rec)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'samples', 'wateen-sample-data.json')
    main(out)
