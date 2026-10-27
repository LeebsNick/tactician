local F        = dofile('tactician/tests/fixtures.lua');
local document = require('lib.document');
local view     = require('lib.view');

local cat = F.catalog();

test('rows read as sentences, with the inert reason beside the rules that can never fire', function()
    local doc = document.parse({
        'party hpp_lt:50 ma:highest:Cure',
        'off self not_status:Protect and mpp_lt:90 ma:Protect retry:10',
        'target casting_ma ma:Stun',
        '# a note',
        'bad line',
        'target always rattack',
        'self always item:Hi-Potion',
    });
    local rows = view.rows(doc, cat, F.snapshot());
    assert_eq(rows[1], { n = 1, enabled = true, scope = 'Party member', condition = 'HP below 50%', action = 'Cast best Cure', retry = 0 });
    assert_eq(rows[2].enabled, false);
    assert_eq(rows[2].condition, 'Missing effect Protect and MP below 90%');
    assert_eq(rows[2].action, 'Cast Protect');
    assert_eq(rows[2].retry, 10);
    assert_eq(rows[3].note, 'not learned');
    assert_eq(rows[4], { n = 4, raw = '# a note' });
    assert_eq(rows[5].raw, 'bad line');
    assert_eq(type(rows[5].error), 'string');
    assert_eq(rows[6].action, 'Ranged attack');
    assert_eq(rows[7].action, 'Use Hi-Potion');
end);

test('the condition list for a scope holds only what can be read for it', function()
    local keys = {};
    for _, c in ipairs(view.condition_options('target')) do keys[c.key] = true; end
    assert_eq(keys.hpp_lt, true);
    assert_eq(keys.casting_ma, true);
    assert_eq(keys.mpp_lt, nil);
    assert_eq(keys.status, nil);
    keys = {};
    for _, c in ipairs(view.condition_options('pet')) do keys[c.key] = true; end
    assert_eq(keys.tp_gte, true);
    assert_eq(keys.status, nil);
end);

test('spell picks are what my main or sub job can cast at some level, greyed with the reason while I cannot cast them yet', function()
    local snap = F.snapshot();
    local picks = view.picks('spell', cat, snap);
    local by = {};
    for _, p in ipairs(picks) do by[p.value] = p; end
    assert_eq(by['Cure III'], { label = 'Cure III', value = 'Cure III' });
    assert_eq(by['Stun'], nil, 'a dark knight spell is not offered to a WHM/BLM');
    assert_eq(by['Utsusemi: Ichi'], nil, 'nor a ninja one');
    assert_eq(by['Sleepga'], { label = 'Sleepga', value = 'Sleepga', dim = true, why = 'not learned' }, 'BLM 31 is within the sub job: listed, greyed');
    assert_eq(by['Fire'], { label = 'Fire', value = 'Fire' }, 'a sub job spell at level');
    snap.known.spell[145] = true;
    by = {};
    for _, p in ipairs(view.picks('spell', cat, snap)) do by[p.value] = p; end
    assert_eq(by['Fire II'].why, 'needs BLM 38');
    assert_eq(picks[1].value < picks[2].value, true, 'sorted by name');
    local count = 0;
    for _, p in ipairs(picks) do if p.value == 'Sleepga' then count = count + 1; end end
    assert_eq(count, 1, 'a duplicated name is offered once');
end);

test('a change of job changes which spells are offered', function()
    local snap = F.snapshot();
    snap.me.sub, snap.me.sublevel = 13, 12;
    local by = {};
    for _, p in ipairs(view.picks('spell', cat, snap)) do by[p.value] = p; end
    assert_eq(by['Utsusemi: Ichi'], { label = 'Utsusemi: Ichi', value = 'Utsusemi: Ichi', dim = true, why = 'not learned' }, 'with NIN as the sub job');
    assert_eq(by['Sleepga'], nil, 'and the black magic went with BLM');
    snap.me.job, snap.me.level = 8, 41;
    by = {};
    for _, p in ipairs(view.picks('spell', cat, snap)) do by[p.value] = p; end
    assert_eq(by['Stun'], { label = 'Stun', value = 'Stun', dim = true, why = 'not learned' }, 'a DRK sees Stun');
    assert_eq(by['Cure'], nil);
end);

test('family picks are the families my job has a tier of, greyed when no tier is learned or the learned tier is above my level', function()
    local by = {};
    for _, p in ipairs(view.picks('family', cat, F.snapshot())) do by[p.value] = p; end
    assert_eq(by['Cure'], { label = 'Cure', value = 'Cure' });
    assert_eq(by['Sleepga'], { label = 'Sleepga', value = 'Sleepga', dim = true, why = 'not learned' });
    assert_eq(by['Stun'], nil, 'no tier of it is for a WHM/BLM');
    assert_eq(by['Utsusemi'], nil);
    assert_eq(by['Curing Waltz'], nil, 'ability families belong to the ability family list');
    local snap = F.snapshot();
    snap.known.spell[144], snap.known.spell[145] = nil, true;
    by = {};
    for _, p in ipairs(view.picks('family', cat, snap)) do by[p.value] = p; end
    assert_eq(by['Fire'], { label = 'Fire', value = 'Fire', dim = true, why = 'needs BLM 38' }, 'the one learned tier is above the sub job level');
    snap = F.snapshot();
    snap.me.level = 5;
    by = {};
    for _, p in ipairs(view.picks('family', cat, snap)) do by[p.value] = p; end
    assert_eq(by['Protect'].why, 'needs WHM 7', 'the level the family first becomes usable at, not the highest learned tier');
end);

test('ability and weapon skill picks are what I have now: the client does not say what a job gets later', function()
    local snap = F.snapshot();
    assert_eq(view.picks('ability', cat, snap), { { label = 'Divine Seal', value = 'Divine Seal' } }, 'Provoke is not mine');
    assert_eq(view.picks('ability_family', cat, snap), { { label = 'Divine Seal', value = 'Divine Seal' } });
    snap.known.ability[608] = true;
    assert_eq(view.picks('ability_family', cat, snap)[1].value, 'Curing Waltz', 'one tier learned lists the family');
    assert_eq(view.picks('weaponskill', cat, snap), { { label = 'Fast Blade', value = 'Fast Blade' } }, 'Combo is not mine');
end);

test('item and status picks are not cut down: they have no job or learned state', function()
    local snap = F.snapshot();
    assert_eq(view.picks('item', cat, snap), { { label = 'Hi-Potion', value = 'Hi-Potion' } });
    assert_eq(view.picks('none', cat, snap), {});
    local statuses = view.picks('status', cat, snap);
    assert_eq(statuses[1].value, 'Bewildered Daze', 'a name the DATs repeat across ids is listed once');
    assert_eq(statuses[2].value, 'Copy Image');
    assert_eq(#statuses, 5, 'bracketed placeholders like (None) are left out');
end);

test('a rule naming a spell or weapon skill the picker would not offer still reads out with that name', function()
    local doc = document.parse({ 'target always ma:Stun', 'self tp_gte:1000 ws:Combo' });
    local rows = view.rows(doc, cat, F.snapshot());
    assert_eq(rows[1].action, 'Cast Stun');
    assert_eq(rows[1].note, 'not learned');
    assert_eq(rows[2].action, 'Weapon skill Combo');
    assert_eq(rows[2].note, 'not learned');
end);

test('the pick list a kind needs follows the vocabulary', function()
    assert_eq(view.pick_kind({ reaction = 'ma', selector = 'highest' }), 'family');
    assert_eq(view.pick_kind({ reaction = 'ja', selector = 'highest' }), 'ability_family');
    assert_eq(view.pick_kind({ reaction = 'ja', selector = 'specific' }), 'ability');
    assert_eq(view.pick_kind({ reaction = 'ws', selector = 'specific' }), 'weaponskill');
    assert_eq(view.pick_kind({ reaction = 'rattack' }), 'none');
    assert_eq(view.pick_kind({ reaction = 'item', selector = 'specific' }), 'item');
end);

test('the summary counts rules on, off and inert', function()
    local doc = document.parse({ 'party hpp_lt:50 ma:highest:Cure', 'off self always ja:Provoke', 'target casting_ma ma:Stun', '# note' });
    assert_eq(view.summary(doc, cat, F.snapshot()), { rules = 3, on = 2, inert = 1 });
end);

test('the last fired rule is the one with the latest fire time', function()
    local engine = require('lib.engine');
    local eng = engine.new();
    assert_eq(view.last_fired(eng), nil);
    eng = engine.fired(eng, 2, 10);
    eng = engine.fired(eng, 1, 12);
    assert_eq(view.last_fired(eng), { index = 1, at = 12 });
    eng = engine.fired(eng, 2, 15);
    assert_eq(view.last_fired(eng), { index = 2, at = 15 });
end);

test('the If cell gives its dropdowns what the column leaves after the arguments, never under the minimum', function()
    local rule = require('lib.rule');
    local one = rule.parse('self always ma:Stun');
    assert_eq(view.if_width(1000, one, 8), 1000 - view.MIN.scope - view.MIN.button - 8 * 2, 'a scope box, one dropdown and the + button');
    local two = rule.parse('party hpp_lt:50 and not_status:Weakness ma:"Cure III"');
    assert_eq(view.if_width(1000, two, 8), (1000 - view.MIN.scope * 2 - view.MIN.arg * 2 - view.MIN.logic - view.MIN.button - 8 * 7) / 2);
    assert_eq(view.if_width(200, two, 8), view.MIN.combo, 'a narrow column floors at the minimum');
end);

test('a condition on another scope is read out with that scope first', function()
    local rule = require('lib.rule');
    local r = rule.parse('self tp_gte:1000 and target.hpp_gte:10 ws:"Fast Blade"');
    assert_eq(view.if_text(r), 'TP at least 1000 and My target: HP at least 10%');
end);

test('ws_within reads out in seconds', function()
    local rule = require('lib.rule');
    assert_eq(view.if_text(rule.parse('self tp_gte:1000 and ws_within:6 ws:"Fast Blade"')), 'TP at least 1000 and Party weapon skill within 6s');
end);
