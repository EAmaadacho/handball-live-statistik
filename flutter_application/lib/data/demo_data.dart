/// Example data from the prototype: TV Mettmann against HSG Hilden, game 17.
///
/// [DemoGameSource] starts from here and changes a copy while ticking.
library;

import 'models.dart';

const demoMettmann = Team(
  id: 'tvm',
  name: 'TV Mettmann',
  shortName: 'TVM',
  players: [
    Player(
        id: 'nora1',
        number: 1,
        firstName: 'Nora',
        lastName: 'Neumann',
        isGoalkeeper: true),
    Player(id: 'max7', number: 7, firstName: 'Max', lastName: 'Mustermann'),
    Player(id: 'lisa12', number: 12, firstName: 'Lisa', lastName: 'Mustermann'),
    Player(id: 'jonas4', number: 4, firstName: 'Jonas', lastName: 'Becker'),
    Player(id: 'ben5', number: 5, firstName: 'Ben', lastName: 'Schulz'),
    Player(id: 'paul11', number: 11, firstName: 'Paul', lastName: 'Wagner'),
    Player(id: 'finn23', number: 23, firstName: 'Finn', lastName: 'Krüger'),
    Player(id: 'tom9', number: 9, firstName: 'Tom', lastName: 'Neumann'),
    Player(id: 'erik15', number: 15, firstName: 'Erik', lastName: 'Hoffmann'),
    Player(
        id: 'mia16',
        number: 16,
        firstName: 'Mia',
        lastName: 'Schröder',
        isGoalkeeper: true),
  ],
  officials: [
    Official(letter: 'A', name: 'Sven Krause', role: 'Trainer'),
    Official(letter: 'B', name: 'Anja Wolf', role: 'Co-Trainerin'),
    Official(letter: 'C', name: 'Dirk Meier', role: 'Betreuer'),
  ],
);

const demoHilden = Team(
  id: 'hsg',
  name: 'HSG Hilden',
  shortName: 'HSG',
  players: [
    Player(
        id: 'a1',
        number: 1,
        firstName: 'Lukas',
        lastName: 'Kern',
        isGoalkeeper: true),
    Player(id: 'a3', number: 3, firstName: 'Jan', lastName: 'Vogel'),
    Player(id: 'a5', number: 5, firstName: 'Jan', lastName: 'Becker'),
    Player(id: 'a8', number: 8, firstName: 'Nico', lastName: 'Hahn'),
    Player(id: 'a10', number: 10, firstName: 'Kai', lastName: 'Roth'),
    Player(id: 'a6', number: 6, firstName: 'Timo', lastName: 'Brandt'),
    Player(id: 'a14', number: 14, firstName: 'Ole', lastName: 'Fischer'),
    Player(id: 'a19', number: 19, firstName: 'Leon', lastName: 'Kraus'),
    Player(id: 'a2', number: 2, firstName: 'Tim', lastName: 'Lang'),
    Player(id: 'a17', number: 17, firstName: 'Moritz', lastName: 'Klein'),
    Player(
        id: 'a12',
        number: 12,
        firstName: 'Felix',
        lastName: 'Sommer',
        isGoalkeeper: true),
  ],
  officials: [
    Official(letter: 'A', name: 'Holger Brück', role: 'Trainer'),
    Official(letter: 'B', name: 'Sara Linde', role: 'Betreuerin'),
  ],
);

const demoGame = Game(id: 17, home: demoMettmann, away: demoHilden);

/// 38:47 in the second half, 14:12, Nico (8) sits out a penalty.
const demoState = GameState(
  game: demoGame,
  goals: {Side.home: 14, Side.away: 12},
  clockSeconds: 38 * 60 + 47,
  clockRunning: true,
  timeouts: {Side.home: 1, Side.away: 2},
  penalties: [
    Penalty(side: Side.away, label: '8', secondsLeft: 82, playerId: 'a8')
  ],
  field: {
    Side.home: [
      'nora1',
      'paul11',
      'max7',
      'lisa12',
      'finn23',
      'jonas4',
      'ben5'
    ],
    Side.away: ['a1', 'a14', 'a6', 'a5', null, 'a10', 'a3'],
  },
  bench: {
    Side.home: ['tom9', 'erik15', 'mia16'],
    Side.away: ['a19', 'a2', 'a17', 'a12'],
  },
  cards: {'jonas4': CardMark.yellow, 'away:A': CardMark.yellow},
  halftimeScore: '8:7',
  events: [
    GameEvent(
        number: 6,
        playerId: 'max7',
        clockSeconds: 38 * 60 + 12,
        kind: EventKind.goal,
        side: Side.home,
        who: '7 Max Mustermann',
        homeGoals: 14,
        awayGoals: 12),
    GameEvent(
        number: 5,
        playerId: 'a3',
        clockSeconds: 37 * 60 + 40,
        kind: EventKind.save,
        side: Side.away,
        who: '3 Jan Vogel',
        homeGoals: 13,
        awayGoals: 12),
    GameEvent(
        number: 4,
        playerId: 'a8',
        clockSeconds: 37 * 60 + 3,
        kind: EventKind.twoMinutes,
        side: Side.away,
        who: '8 Nico Hahn',
        homeGoals: 13,
        awayGoals: 12),
    GameEvent(
        number: 3,
        playerId: 'a10',
        clockSeconds: 36 * 60 + 21,
        kind: EventKind.goal,
        side: Side.away,
        who: '10 Kai Roth',
        homeGoals: 13,
        awayGoals: 12),
    GameEvent(
        number: 2,
        playerId: 'max7',
        clockSeconds: 35 * 60 + 50,
        kind: EventKind.sevenMeterGoal,
        side: Side.home,
        who: '7 Max Mustermann',
        homeGoals: 13,
        awayGoals: 11),
    GameEvent(
        number: 1,
        clockSeconds: 34 * 60 + 2,
        kind: EventKind.timeout,
        side: Side.away,
        who: 'HSG Hilden',
        homeGoals: 12,
        awayGoals: 11),
  ],
  stats: {
    'nora1': PlayerStats(saves: 9, goalsAgainst: 12),
    'max7': PlayerStats(
        goals: 5,
        shots: 7,
        sevenMeterGoals: 2,
        sevenMeterShots: 2,
        technicalFaults: 1),
    'lisa12': PlayerStats(goals: 3, shots: 4),
    'jonas4': PlayerStats(goals: 2, shots: 3, yellowCards: 1),
    'ben5': PlayerStats(goals: 1, shots: 3),
    'paul11': PlayerStats(goals: 1, shots: 2),
    'finn23': PlayerStats(goals: 2, shots: 2),
    'a1': PlayerStats(saves: 6, goalsAgainst: 14),
    'a3': PlayerStats(goals: 3, shots: 5),
    'a5': PlayerStats(goals: 2, shots: 4),
    'a8': PlayerStats(goals: 1, shots: 2, twoMinutes: 1),
    'a10':
        PlayerStats(goals: 4, shots: 6, sevenMeterGoals: 1, sevenMeterShots: 2),
    'a6': PlayerStats(goals: 2, shots: 3),
    'a14': PlayerStats(shots: 1, technicalFaults: 2),
  },
);
