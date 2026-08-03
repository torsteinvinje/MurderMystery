// REAL integration tests against the actual Skjult agenda RPCs — not mocks.
// They require a DISPOSABLE Supabase test project with the full schema
// migrated (including 00011) and app_feature_flags.SABOTEUR_GAME_ENABLED = true.
//
// NEVER point these at a production database: they create real games and
// participants as a side effect of testing.
//
// Configure via env vars:
//   SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY
// If either is missing, every test here is SKIPPED — not faked as passing and
// not silently omitted; the skip reason is printed in the output. This
// sandbox/CI has no such database, so in that environment this file reports
// "skipped", which is the true and complete state of verification for these
// properties, not "passed".
//
// These build up shared state step by step (a scripted playthrough) rather
// than being isolated unit tests — a deliberate trade-off for this suite.
import { describe, it, expect, beforeAll } from 'vitest'
import { createClient } from '@supabase/supabase-js'

const TEST_URL = process.env.SUPABASE_TEST_URL
const TEST_KEY = process.env.SUPABASE_TEST_ANON_KEY
const hasTestDb = Boolean(TEST_URL && TEST_KEY)

describe.skipIf(!hasTestDb)('Skjult agenda (standalone) — live integration', () => {
  let supabase
  let gameA, gameB // two unrelated games, to prove they cannot see each other
  let sab, loyal, loyal2
  let sabId, loyalId, loyal2Id

  async function call(name, params) {
    const { data, error } = await supabase.rpc(name, params)
    if (error) throw new Error(error.message)
    return data
  }

  const participants = async () => (await call('host_get_saboteur_game', { p_host_token: gameA.host_token })).participants

  beforeAll(async () => {
    supabase = createClient(TEST_URL, TEST_KEY)

    gameA = await call('create_saboteur_game', { p_title: 'Test A', p_know_each_other: false })
    gameB = await call('create_saboteur_game', { p_title: 'Test B', p_know_each_other: false })

    sab = await call('join_saboteur_game', { p_code: gameA.code, p_name: 'Sabotør Sara' })
    loyal = await call('join_saboteur_game', { p_code: gameA.code, p_name: 'Lojal Lars' })
    loyal2 = await call('join_saboteur_game', { p_code: gameA.code, p_name: 'Lojal Lise' })

    const list = await participants()
    sabId = list.find((p) => p.display_name === 'Sabotør Sara').id
    loyalId = list.find((p) => p.display_name === 'Lojal Lars').id
    loyal2Id = list.find((p) => p.display_name === 'Lojal Lise').id

    await call('host_set_participant_role', { p_host_token: gameA.host_token, p_participant_id: sabId, p_role: 'SABOTEUR' })
    await call('host_set_participant_role', { p_host_token: gameA.host_token, p_participant_id: loyalId, p_role: 'LOYAL' })
    await call('host_set_participant_role', { p_host_token: gameA.host_token, p_participant_id: loyal2Id, p_role: 'LOYAL' })
  })

  // --- Standalone identity / authorization -----------------------------------

  it('a game gets its own join code and host token', () => {
    expect(gameA.code).toMatch(/^[A-Z0-9]{4}$/)
    expect(gameA.host_token).toBeTruthy()
    expect(gameA.code).not.toBe(gameB.code)
  })

  it('rejects an invalid host token', async () => {
    await expect(
      call('host_get_saboteur_game', { p_host_token: '00000000-0000-0000-0000-000000000000' })
    ).rejects.toThrow()
  })

  it('rejects an invalid player token', async () => {
    await expect(
      call('get_my_saboteur_brief', { p_player_token: '00000000-0000-0000-0000-000000000000' })
    ).rejects.toThrow()
  })

  it('host B cannot touch game A\'s participants', async () => {
    await expect(
      call('host_set_participant_role', { p_host_token: gameB.host_token, p_participant_id: sabId, p_role: 'LOYAL' })
    ).rejects.toThrow()
  })

  it('joining an unknown code fails', async () => {
    await expect(call('join_saboteur_game', { p_code: 'ZZZZ', p_name: 'Ingen' })).rejects.toThrow()
  })

  // --- Role assignment + lifecycle -------------------------------------------

  it('needs both roles present before it can start', async () => {
    const solo = await call('create_saboteur_game', {})
    const p = await call('join_saboteur_game', { p_code: solo.code, p_name: 'Alene' })
    const list = (await call('host_get_saboteur_game', { p_host_token: solo.host_token })).participants
    await call('host_set_participant_role', { p_host_token: solo.host_token, p_participant_id: list[0].id, p_role: 'LOYAL' })
    await expect(
      call('host_set_saboteur_status', { p_host_token: solo.host_token, p_status: 'active' })
    ).rejects.toThrow(/minst én Sabotør/)
    expect(p.player_token).toBeTruthy()
  })

  it('rejects an illegal transition (draft straight to voting)', async () => {
    await expect(
      call('host_set_saboteur_status', { p_host_token: gameA.host_token, p_status: 'voting' })
    ).rejects.toThrow()
  })

  it('starts, then locks role changes', async () => {
    await call('host_set_saboteur_status', { p_host_token: gameA.host_token, p_status: 'active' })
    await expect(
      call('host_set_participant_role', { p_host_token: gameA.host_token, p_participant_id: loyalId, p_role: 'SABOTEUR' })
    ).rejects.toThrow(/utkast/)
  })

  it('players cannot join once the game has started', async () => {
    await expect(
      call('join_saboteur_game', { p_code: gameA.code, p_name: 'For sent' })
    ).rejects.toThrow()
  })

  // --- Per-viewer payload isolation ------------------------------------------

  it('each player sees only their own role and nothing of the others', async () => {
    const sabBrief = await call('get_my_saboteur_brief', { p_player_token: sab.player_token })
    expect(sabBrief.my_role).toBe('SABOTEUR')
    expect(sabBrief.tasks).toEqual([]) // tasks are Lojal-only

    const loyalBrief = await call('get_my_saboteur_brief', { p_player_token: loyal.player_token })
    expect(loyalBrief.my_role).toBe('LOYAL')
    expect(loyalBrief.objectives).toEqual([]) // objectives are Sabotør-only

    // Nothing in a player payload should enumerate other participants' roles
    // while the game is running.
    expect(JSON.stringify(loyalBrief)).not.toContain('SABOTEUR')
  })

  it('know_each_other off: a Sabotør sees no fellow Sabotør names', async () => {
    const brief = await call('get_my_saboteur_brief', { p_player_token: sab.player_token })
    expect(brief.fellow_saboteurs).toEqual([])
  })

  // --- Objectives: host-reviewed, idempotent scoring -------------------------

  describe('objectives', () => {
    let objectiveId

    beforeAll(async () => {
      const res = await call('host_upsert_objective', {
        p_host_token: gameA.host_token, p_participant_id: sabId, p_title: 'Test-mål', p_points: 10,
      })
      objectiveId = res.id
    })

    it('a Lojal cannot claim the Sabotør\'s objective', async () => {
      await expect(
        call('claim_saboteur_objective', { p_player_token: loyal.player_token, p_objective_id: objectiveId })
      ).rejects.toThrow()
    })

    it('the assigned Sabotør claims it', async () => {
      const res = await call('claim_saboteur_objective', { p_player_token: sab.player_token, p_objective_id: objectiveId })
      expect(res.status).toBe('claimed')
    })

    it('approving twice never awards points twice', async () => {
      const first = await call('host_decide_objective_claim', {
        p_host_token: gameA.host_token, p_objective_id: objectiveId, p_approve: true,
      })
      expect(first.points_awarded).toBe(true)

      for (let i = 0; i < 3; i++) {
        const retry = await call('host_decide_objective_claim', {
          p_host_token: gameA.host_token, p_objective_id: objectiveId, p_approve: true,
        })
        expect(retry.already_decided).toBe(true)
      }

      const list = await participants()
      expect(list.find((p) => p.id === sabId).points).toBe(10) // NOT 40
    })

    it('a rejected claim awards zero points', async () => {
      const obj = await call('host_upsert_objective', {
        p_host_token: gameA.host_token, p_participant_id: sabId, p_title: 'Avslås', p_points: 99,
      })
      await call('claim_saboteur_objective', { p_player_token: sab.player_token, p_objective_id: obj.id })
      const decision = await call('host_decide_objective_claim', {
        p_host_token: gameA.host_token, p_objective_id: obj.id, p_approve: false,
      })
      expect(decision.points_awarded).toBe(false)

      const list = await participants()
      expect(list.find((p) => p.id === sabId).points).toBe(10) // unchanged, not 109
    })
  })

  // --- Tasks + hint audience --------------------------------------------------

  describe('tasks and hint release', () => {
    it('an assignee-only hint reaches nobody else', async () => {
      const task = await call('host_upsert_task', {
        p_host_token: gameA.host_token, p_participant_id: loyalId, p_title: 'Hemmelig',
        p_hint_text: 'HINT-EN', p_hint_audience: 'assignee',
      })
      await call('claim_saboteur_task', { p_player_token: loyal.player_token, p_task_id: task.id })
      await call('host_decide_task_claim', { p_host_token: gameA.host_token, p_task_id: task.id, p_approve: true })

      const mine = await call('get_my_saboteur_brief', { p_player_token: loyal.player_token })
      expect(mine.hints.some((h) => h.hint_text === 'HINT-EN')).toBe(true)

      const other = await call('get_my_saboteur_brief', { p_player_token: loyal2.player_token })
      expect(other.hints.some((h) => h.hint_text === 'HINT-EN')).toBe(false)

      const sabView = await call('get_my_saboteur_brief', { p_player_token: sab.player_token })
      expect(sabView.hints).toEqual([]) // Sabotører never receive Lojal hints
    })

    it('an all_loyal hint reaches every Lojal exactly once, and no Sabotør', async () => {
      const task = await call('host_upsert_task', {
        p_host_token: gameA.host_token, p_participant_id: loyalId, p_title: 'Gruppe',
        p_hint_text: 'HINT-ALLE', p_hint_audience: 'all_loyal',
      })
      await call('claim_saboteur_task', { p_player_token: loyal.player_token, p_task_id: task.id })
      await call('host_decide_task_claim', { p_host_token: gameA.host_token, p_task_id: task.id, p_approve: true })
      const retry = await call('host_decide_task_claim', { p_host_token: gameA.host_token, p_task_id: task.id, p_approve: true })
      expect(retry.already_decided).toBe(true)

      const one = await call('get_my_saboteur_brief', { p_player_token: loyal.player_token })
      const two = await call('get_my_saboteur_brief', { p_player_token: loyal2.player_token })
      expect(one.hints.filter((h) => h.hint_text === 'HINT-ALLE').length).toBe(1) // not duplicated
      expect(two.hints.some((h) => h.hint_text === 'HINT-ALLE')).toBe(true)

      const sabView = await call('get_my_saboteur_brief', { p_player_token: sab.player_token })
      expect(sabView.hints.some((h) => h.hint_text === 'HINT-ALLE')).toBe(false)
    })
  })

  // --- Voting ------------------------------------------------------------------

  describe('voting', () => {
    let round

    it('host opens a round', async () => {
      const res = await call('host_open_voting_round', { p_host_token: gameA.host_token })
      round = res.round_id
      expect(round).toBeTruthy()
    })

    it('a Sabotør gets no targets and cannot vote', async () => {
      expect(await call('get_saboteur_ballot_targets', { p_player_token: sab.player_token })).toEqual([])
      await expect(
        call('cast_saboteur_ballot', { p_player_token: sab.player_token, p_round_id: round, p_target_participant_id: loyalId })
      ).rejects.toThrow()
    })

    it('a Lojal votes once; a second vote is rejected', async () => {
      const targets = await call('get_saboteur_ballot_targets', { p_player_token: loyal.player_token })
      expect(targets.length).toBeGreaterThan(0)

      await call('cast_saboteur_ballot', { p_player_token: loyal.player_token, p_round_id: round, p_target_participant_id: sabId })
      await expect(
        call('cast_saboteur_ballot', { p_player_token: loyal.player_token, p_round_id: round, p_target_participant_id: sabId })
      ).rejects.toThrow(/allerede stemt/)
    })

    it('votes stay secret from the host until closed AND revealed', async () => {
      const open = await call('host_get_saboteur_game', { p_host_token: gameA.host_token })
      expect(open.current_round.tally).toBeNull()
      expect(open.current_round.ballot_count).toBeGreaterThan(0)

      await call('host_close_voting_round', { p_host_token: gameA.host_token, p_round_id: round })
      const closed = await call('host_get_saboteur_game', { p_host_token: gameA.host_token })
      expect(closed.current_round.tally).toBeNull() // closed but not revealed: still secret

      await call('host_reveal_voting_round', { p_host_token: gameA.host_token, p_round_id: round })
      const revealed = await call('host_get_saboteur_game', { p_host_token: gameA.host_token })
      expect(revealed.current_round.tally).not.toBeNull()
    })

    it('a late vote is rejected', async () => {
      await expect(
        call('cast_saboteur_ballot', { p_player_token: loyal2.player_token, p_round_id: round, p_target_participant_id: sabId })
      ).rejects.toThrow()
    })
  })

  // --- Ending ------------------------------------------------------------------

  describe('ending the game', () => {
    it('a finished vote does NOT reveal roles', async () => {
      const brief = await call('get_my_saboteur_brief', { p_player_token: loyal.player_token })
      expect(brief.reveal).toBeNull()
    })

    it('ending the game reveals roles', async () => {
      await call('host_end_saboteur_game', { p_host_token: gameA.host_token })
      const brief = await call('get_my_saboteur_brief', { p_player_token: loyal.player_token })
      expect(brief.reveal).not.toBeNull()
      expect(brief.reveal.participants.length).toBe(3)
      expect(typeof brief.reveal.my_points).toBe('number')
      expect(brief.reveal.leaderboard).toBeNull() // show_leaderboard defaults off
    })
  })
})

if (!hasTestDb) {
  describe('Skjult agenda (standalone) — live integration', () => {
    it.skip(
      'SKIPPED: set SUPABASE_TEST_URL and SUPABASE_TEST_ANON_KEY to a disposable ' +
      'test project (schema migrated, SABOTEUR_GAME_ENABLED=true) to run these ' +
      '— never point them at a production database',
      () => {}
    )
  })
}
