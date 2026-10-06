local vocab = require('lib.vocab');

test('every target, condition, reaction and selector is found by its key', function()
    for _, list in ipairs({ vocab.targets, vocab.conditions, vocab.reactions, vocab.selectors }) do
        for _, entry in ipairs(list) do
            assert_eq(vocab.lookup(list, entry.key), entry, entry.key);
        end
    end
    assert_eq(vocab.target('nobody'), nil);
end);

test('keys carry the CatsEyeXI gambit enum values, and client-only additions carry none', function()
    assert_eq(vocab.target('self').id, 0);
    assert_eq(vocab.target('party').id, 1);
    assert_eq(vocab.target('target').id, 2);
    assert_eq(vocab.target('party_dead').id, 10);
    assert_eq(vocab.target('pet').id, nil);
    assert_eq(vocab.condition('hpp_lt').id, 1);
    assert_eq(vocab.condition('tp_gte').id, 5);
    assert_eq(vocab.condition('not_status').id, 7);
    assert_eq(vocab.condition('casting_ma').id, 17);
    assert_eq(vocab.condition('hp_missing').id, 24);
    assert_eq(vocab.reaction('ma').id, 2);
    assert_eq(vocab.reaction('rattack').id, 1);
    assert_eq(vocab.reaction('item').id, nil);
    assert_eq(vocab.selector('highest').id, 0);
    assert_eq(vocab.selector('specific').id, 2);
end);

test('a condition fits a scope only when that scope can be read for it', function()
    assert_eq(vocab.fits('hpp_lt', 'target'), true);
    assert_eq(vocab.fits('mpp_lt', 'target'), false, 'a monster has no visible MP');
    assert_eq(vocab.fits('tp_gte', 'pet'), true);
    assert_eq(vocab.fits('status', 'pet'), false, 'pet statuses are not sent to the client');
    assert_eq(vocab.fits('status', 'party'), true);
    assert_eq(vocab.fits('hp_missing', 'party'), false, 'only my own max HP is known');
    assert_eq(vocab.fits('hp_missing', 'self'), true);
    assert_eq(vocab.fits('casting_ma', 'self'), false);
    assert_eq(vocab.fits('casting_ma', 'target'), true);
    assert_eq(vocab.fits('always', 'party_dead'), true);
end);

test('a reaction allows only its own selectors', function()
    assert_eq(vocab.allows('ma', 'highest'), true);
    assert_eq(vocab.allows('ja', 'highest'), true);
    assert_eq(vocab.allows('ws', 'highest'), false);
    assert_eq(vocab.allows('ws', 'specific'), true);
    assert_eq(vocab.allows('rattack', nil), true);
    assert_eq(vocab.allows('rattack', 'specific'), false);
    assert_eq(vocab.allows('item', 'specific'), true);
end);

test('actions that land only on a monster are marked so', function()
    assert_eq(vocab.reaction('ws').aim, 'enemy');
    assert_eq(vocab.reaction('rattack').aim, 'enemy');
    assert_eq(vocab.reaction('ma').aim, 'any');
end);

test('party roles follow the LandSandBoat job sets', function()
    assert_eq(vocab.target('tank').jobs, { [7] = true, [22] = true });
    assert_eq(vocab.target('ranged').jobs, { [11] = true, [17] = true });
    assert_eq(vocab.target('melee').jobs[16], true, 'blue mage counts as melee');
    assert_eq(vocab.target('caster').jobs[16], true, 'and as a caster');
    assert_eq(vocab.target('caster').jobs[1], nil);
end);

test('the kinds list has one entry per legal reaction and selector pair', function()
    local keys = {};
    for _, kind in ipairs(vocab.kinds) do keys[kind.key] = true; end
    assert_eq(keys, { ['ma:specific'] = true, ['ma:highest'] = true, ['ja:specific'] = true, ['ja:highest'] = true,
                      ['ws:specific'] = true, ['rattack'] = true, ['item:specific'] = true });
    assert_eq(vocab.kind('ma', 'highest').key, 'ma:highest');
    assert_eq(vocab.kind('rattack', nil).key, 'rattack');
    assert_eq(vocab.kind('ws', 'highest'), nil);
end);
