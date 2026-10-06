local F       = dofile('tactician/tests/fixtures.lua');
local catalog = require('lib.catalog');

test('spells, abilities, weapon skills, statuses and items are found by name, case-insensitively', function()
    local cat = F.catalog();
    assert_eq(catalog.spell(cat, 'cure iii').id, 3);
    assert_eq(catalog.spell(cat, 'Utsusemi: Ichi').id, 338);
    assert_eq(catalog.ability(cat, 'provoke').id, 547);
    assert_eq(catalog.weaponskill(cat, 'Fast Blade').id, 32);
    assert_eq(catalog.status(cat, 'protect'), 40);
    assert_eq(catalog.item(cat, 'hi-potion').id, 4116);
    assert_eq(catalog.spell(cat, 'Nothing'), nil);
end);

test('a family lists its tiers in order and is found by its display name', function()
    local cat = F.catalog();
    local cure = catalog.family(cat, 'Cure');
    assert_eq(cure.display, 'Cure');
    local ids = {};
    for _, s in ipairs(cure.tiers) do table.insert(ids, s.id); end
    assert_eq(ids, { 1, 2, 3, 4 });
    assert_eq(catalog.family(cat, 'protectra').tiers[1].id, 125, 'Protectra is its own family, not a Protect tier');
    assert_eq(catalog.family(cat, 'curing waltz').tiers[2].id, 609, 'abilities have families too');
end);

test('a duplicate name keeps the lowest id', function()
    assert_eq(catalog.spell(F.catalog(), 'Sleepga').id, 273);
end);

test('family names are listed once each, sorted, for the picker', function()
    local names = catalog.family_names(F.catalog(), 'spell');
    assert_eq(names[1], 'Cure');
    local seen = {};
    for _, n in ipairs(names) do
        assert_eq(seen[n], nil, n .. ' listed twice');
        seen[n] = true;
    end
    assert_eq(seen['Fire'], true);
    assert_eq(seen['Curing Waltz'], nil, 'ability families are a separate list');
end);
