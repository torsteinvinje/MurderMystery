// REAL integration tests against the actual Skjult agenda RPCs — not mocks,
// not a re-implementation. They require a DISPOSABLE Supabase test project
// with the full schema migrated (including 00009/00010) and
// app_feature_flags.SABOTEUR_GAME_ENABLED = true.
//
// NEVER point these at a production database: they create real games,
// players, and Skjult agenda rows as a side effect of testing.
//
// Configure via env vars:
//   SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY
// If either is missing, every test in this file is SKIPPED, not faked as
// passing and not silently omitted — the skip reason is printed via the
// it.skip() at the bottom, so `npm test` output always says plainly whether
// these ran. This project's sandbox/CI has no such database configured, so
// in that environment this file reports "skipped" — that is the true and
// complete state of verification for these properties in this session, not
// "passed".
//
// These are integration-style tests that build up shared state step by
// step (like a scripted playthrough), not isolated/randomizable unit tests
// — that's a deliberate, standard trade-off for this kind of suite.
import { describe, it, expect, beforeAll } from 'vitest'
import { createClient } from '@supabase/supabase-js'

const TEST_URL = process.env.SUPABASE_TEST_URL
const TEST_KEY = process.env.SUPABASE_TEST_ANON_KEY
const hasTestDb = Boolean(TEST_URL && TEST_KEY)

describe.skipIf(!hasTestDb)('Skjult agenda — live integration (requires SUPABASE_TEST_URL/KEY)', () => {
  let supabase
  let hostA, hostB // hostA runs the party under test; hostB is an unrelated party
  let playerLoyal, playerSaboteur, playerBystander
  let sabA

  async function call(name, params) {
    const { data, error } = await supabase.rpc(name, params)
    if (error) throw new Error(error.message)
    return data
  }

  beforeAll(async () => {
    supabase = createClient(TEST_URL, TEST_KEY)

    hostA = await call('create_game', { p_mystery_id: null })
    hostB = await call('create_game', { p_mystery_id: null })

    playerLoyal = await call('join_game', { p_code: hostA.code, p_name: 'Lojal Larsen' })
    playerSaboteur = await call('join_game', { p_code: hostA.code, p_name: 'Slem Sabotør' })
    playerBystander = await call('join_game', { p_code: hostA.code, p_name: 'Ubuden Gjest' }) // deliberately never assigned

    sabA = await call('host_create_saboteur_game', { p_host_token: hostA.host_token, p_know_each_other: false })
    await call('host_set_participants', {
      p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
      p_assignments: [
        { player_id: playerLoyal.player_id, role: 'LOYAL' },
        { player_id: playerSaboteur.player_id, role: 'SABOTEUR' },
      ],
    })
  })

  // --- Authorization / token validation --------------------------------------

  it('a host RPC rejects a completely invalid host_token', async () => {
    await expect(
      call('host_get_saboteur_game', { p_host_token: '00000000-0000-0000-0000-000000000000', p_saboteur_game_id: sabA.saboteur_game_id })
    ).rejects.toThrow()
  })

  it('a player RPC rejects a completely invalid player_token', async () => {
    await expect(
      call('get_my_saboteur_brief', { p_player_token: '00000000-0000-0000-0000-000000000000', p_saboteur_game_id: sabA.saboteur_game_id })
    ).rejects.toThrow()
  })

  it('cross-game tampering: host B cannot resolve party A\'s Skjult agenda by id', async () => {
    await expect(
      call('host_get_saboteur_game', { p_host_token: hostB.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
    ).rejects.toThrow()
  })

  it('cross-game tampering: a party-A player cannot use party B\'s game_id', async () => {
    await expect(
      call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: hostB.game_id })
    ).rejects.toThrow()
  })

  it('a bystander who was never assigned a role cannot get a brief', async () => {
    await expect(
      call('get_my_saboteur_brief', { p_player_token: playerBystander.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
    ).rejects.toThrow()
  })

  // --- Role assignment validation + state machine ----------------------------

  it('requires at least one Sabotør and one Lojal before the game can start', async () => {
    const solo = await call('create_game', { p_mystery_id: null })
    const soloPlayer = await call('join_game', { p_code: solo.code, p_name: 'Alene' })
    const soloSab = await call('host_create_saboteur_game', { p_host_token: solo.host_token })
    await call('host_set_participants', {
      p_host_token: solo.host_token, p_saboteur_game_id: soloSab.saboteur_game_id,
      p_assignments: [{ player_id: soloPlayer.player_id, role: 'LOYAL' }],
    })
    await expect(
      call('host_set_saboteur_status', { p_host_token: solo.host_token, p_saboteur_game_id: soloSab.saboteur_game_id, p_status: 'active' })
    ).rejects.toThrow(/minst én Sabotør/)
  })

  it('rejects an illegal transition (draft directly to voting)', async () => {
    const g = await call('create_game', { p_mystery_id: null })
    const sab = await call('host_create_saboteur_game', { p_host_token: g.host_token })
    await expect(
      call('host_set_saboteur_status', { p_host_token: g.host_token, p_saboteur_game_id: sab.saboteur_game_id, p_status: 'voting' })
    ).rejects.toThrow()
  })

  it('only one non-archived Skjult agenda per party', async () => {
    await expect(
      call('host_create_saboteur_game', { p_host_token: hostA.host_token })
    ).rejects.toThrow()
  })

  it('roles can only be changed in draft', async () => {
    await call('host_set_saboteur_status', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_status: 'active' })
    await expect(
      call('host_set_participants', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_assignments: [{ player_id: playerBystander.player_id, role: 'LOYAL' }],
      })
    ).rejects.toThrow(/utkast/)
  })

  // --- Per-viewer payload isolation -------------------------------------------

  it('a player sees only their own role, never another participant\'s data', async () => {
    const loyalBrief = await call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
    expect(loyalBrief.my_role).toBe('LOYAL')
    expect(loyalBrief.objectives).toEqual([]) // objectives are Sabotør-only

    const sabBrief = await call('get_my_saboteur_brief', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
    expect(sabBrief.my_role).toBe('SABOTEUR')
    expect(sabBrief.tasks).toEqual([]) // tasks are Lojal-only
  })

  it('know_each_other off: a Sabotør does not see fellow Sabotør names', async () => {
    const brief = await call('get_my_saboteur_brief', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
    expect(brief.fellow_saboteurs).toEqual([])
  })

  // --- Objectives: host-reviewed claims, idempotent scoring -------------------

  describe('objectives', () => {
    let objectiveId
    let saboteurParticipantId

    beforeAll(async () => {
      const game = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      saboteurParticipantId = game.participants.find((p) => p.role === 'SABOTEUR').id
      const res = await call('host_upsert_objective', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_participant_id: saboteurParticipantId, p_title: 'Test-mål', p_points: 10,
      })
      objectiveId = res.id
    })

    it('a Lojal cannot claim the Sabotør\'s objective (it isn\'t theirs)', async () => {
      await expect(
        call('claim_saboteur_objective', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: objectiveId })
      ).rejects.toThrow()
    })

    it('the assigned Sabotør claims it', async () => {
      const res = await call('claim_saboteur_objective', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: objectiveId })
      expect(res.status).toBe('claimed')
    })

    it('host approves it — retries of the SAME approval never award points twice', async () => {
      const first = await call('host_decide_objective_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: objectiveId, p_approve: true })
      expect(first.points_awarded).toBe(true)

      for (let i = 0; i < 3; i++) {
        const retry = await call('host_decide_objective_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: objectiveId, p_approve: true })
        expect(retry.already_decided).toBe(true)
      }

      const game = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      const sab = game.participants.find((p) => p.id === saboteurParticipantId)
      expect(sab.points).toBe(10) // NOT 40 — proves idempotency, not merely "no error"
    })

    it('a rejected claim awards zero points', async () => {
      const obj = await call('host_upsert_objective', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_participant_id: saboteurParticipantId, p_title: 'Skal avslås', p_points: 99,
      })
      await call('claim_saboteur_objective', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: obj.id })
      const decision = await call('host_decide_objective_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_objective_id: obj.id, p_approve: false })
      expect(decision.points_awarded).toBe(false)

      const game = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(game.participants.find((p) => p.id === saboteurParticipantId).points).toBe(10) // unchanged, not 109
    })
  })

  // --- Tasks: hint release respects the chosen audience -----------------------

  describe('tasks and hint release', () => {
    let loyalParticipantId
    let anotherLoyal

    beforeAll(async () => {
      anotherLoyal = await call('join_game', { p_code: hostA.code, p_name: 'Nok en Lojal' })
      // Roles are locked outside draft; this party is already 'active', so
      // reopen roles first (host_set_saboteur_status -> 'draft'), exactly
      // like a real host would via "Åpne roller igjen".
      await call('host_set_saboteur_status', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_status: 'draft' })
      await call('host_set_participants', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_assignments: [{ player_id: anotherLoyal.player_id, role: 'LOYAL' }],
      })
      await call('host_set_saboteur_status', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_status: 'active' })

      const game = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      loyalParticipantId = game.participants.find((p) => p.player_id === playerLoyal.player_id).id
    })

    it('a hint released only to the assignee never reaches a different Lojal', async () => {
      const task = await call('host_upsert_task', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_participant_id: loyalParticipantId, p_title: 'Hemmelig oppgave',
        p_hint_text: 'HEMMELIG-HINT-EN', p_hint_audience: 'assignee',
      })
      await call('claim_saboteur_task', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id })
      await call('host_decide_task_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id, p_approve: true })

      const mine = await call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(mine.hints.some((h) => h.hint_text === 'HEMMELIG-HINT-EN')).toBe(true)

      const theirs = await call('get_my_saboteur_brief', { p_player_token: anotherLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(theirs.hints.some((h) => h.hint_text === 'HEMMELIG-HINT-EN')).toBe(false)

      const sabView = await call('get_my_saboteur_brief', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(sabView.hints).toEqual([]) // Sabotører never receive Lojal hints at all
    })

    it('an all_loyal hint reaches every Lojal but no one else, and approving twice releases it only once', async () => {
      const task = await call('host_upsert_task', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_participant_id: loyalParticipantId, p_title: 'Gruppeoppgave',
        p_hint_text: 'HEMMELIG-HINT-ALLE', p_hint_audience: 'all_loyal',
      })
      await call('claim_saboteur_task', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id })
      await call('host_decide_task_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id, p_approve: true })
      // Retry the same approval — must not error and must not duplicate releases.
      const retry = await call('host_decide_task_claim', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id, p_approve: true })
      expect(retry.already_decided).toBe(true)

      const loyalOne = await call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      const loyalTwo = await call('get_my_saboteur_brief', { p_player_token: anotherLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(loyalOne.hints.filter((h) => h.hint_text === 'HEMMELIG-HINT-ALLE').length).toBe(1) // exactly once, not duplicated
      expect(loyalTwo.hints.some((h) => h.hint_text === 'HEMMELIG-HINT-ALLE')).toBe(true)

      const sabView = await call('get_my_saboteur_brief', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(sabView.hints.some((h) => h.hint_text === 'HEMMELIG-HINT-ALLE')).toBe(false)
    })

    it('a Sabotør cannot claim a task (it isn\'t theirs to claim)', async () => {
      const task = await call('host_upsert_task', {
        p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id,
        p_participant_id: loyalParticipantId, p_title: 'Ikke din oppgave',
      })
      await expect(
        call('claim_saboteur_task', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_task_id: task.id })
      ).rejects.toThrow()
    })
  })

  // --- Voting: one ballot per round, secrecy until reveal ---------------------

  describe('voting', () => {
    let round

    it('host opens a round', async () => {
      const res = await call('host_open_voting_round', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      round = res.round_id
      expect(round).toBeTruthy()
    })

    it('a Sabotør gets no ballot targets and cannot vote', async () => {
      const targets = await call('get_saboteur_ballot_targets', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(targets).toEqual([])
      await expect(
        call('cast_saboteur_ballot', { p_player_token: playerSaboteur.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round, p_target_participant_id: playerLoyal.player_id })
      ).rejects.toThrow()
    })

    it('a Lojal votes once; a second vote in the same round is rejected', async () => {
      const targets = await call('get_saboteur_ballot_targets', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(targets.length).toBeGreaterThan(0)

      await call('cast_saboteur_ballot', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round, p_target_participant_id: targets[0].participant_id })

      await expect(
        call('cast_saboteur_ballot', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round, p_target_participant_id: targets[0].participant_id })
      ).rejects.toThrow(/allerede stemt/)
    })

    it('votes stay secret from the host until the round is BOTH closed and revealed', async () => {
      const whileOpen = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(whileOpen.current_round.tally).toBeNull()
      expect(whileOpen.current_round.ballot_count).toBeGreaterThan(0) // count visible; targets are not

      await call('host_close_voting_round', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round })
      const closed = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(closed.current_round.tally).toBeNull() // closed but not yet revealed: still secret

      await call('host_reveal_voting_round', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round })
      const revealed = await call('host_get_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(revealed.current_round.tally).not.toBeNull()
    })

    it('a late vote (round already closed) is rejected', async () => {
      await expect(
        call('cast_saboteur_ballot', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id, p_round_id: round, p_target_participant_id: playerSaboteur.player_id })
      ).rejects.toThrow()
    })
  })

  // --- Ending: reveal is an explicit act, not implied by a closed vote --------

  describe('ending the game', () => {
    it('roles are NOT revealed to players merely because a vote round happened', async () => {
      const brief = await call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(brief.reveal).toBeNull()
    })

    it('ending the game reveals roles to players', async () => {
      await call('host_end_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      const brief = await call('get_my_saboteur_brief', { p_player_token: playerLoyal.player_token, p_saboteur_game_id: sabA.saboteur_game_id })
      expect(brief.reveal).not.toBeNull()
      expect(brief.reveal.participants.length).toBeGreaterThanOrEqual(2)
      expect(typeof brief.reveal.my_points).toBe('number')
    })

    it('archiving frees up the party for a brand new Skjult agenda', async () => {
      await call('host_archive_saboteur_game', { p_host_token: hostA.host_token, p_saboteur_game_id: sabA.saboteur_game_id })
      const fresh = await call('host_create_saboteur_game', { p_host_token: hostA.host_token })
      expect(fresh.saboteur_game_id).toBeTruthy()
    })
  })
})

if (!hasTestDb) {
  describe('Skjult agenda — live integration', () => {
    it.skip(
      'SKIPPED: set SUPABASE_TEST_URL and SUPABASE_TEST_ANON_KEY to a disposable ' +
      'test project (full schema migrated, SABOTEUR_GAME_ENABLED=true) to run these ' +
      '— never point them at a production database',
      () => {}
    )
  })
}
