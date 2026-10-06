local tiers = require('lib.tiers');

test('a roman numeral suffix is the tier and the rest is the family', function()
    assert_eq({ tiers.split('Cure III') }, { 'cure', 3 });
    assert_eq({ tiers.split('Protectra V') }, { 'protectra', 5 });
    assert_eq({ tiers.split('Fire IV') }, { 'fire', 4 });
    assert_eq({ tiers.split('Thunder VI') }, { 'thunder', 6 });
end);

test('a name without a numeral is tier one of its own family', function()
    assert_eq({ tiers.split('Cure') }, { 'cure', 1 });
    assert_eq({ tiers.split('Haste') }, { 'haste', 1 });
    assert_eq({ tiers.split('Curaga') }, { 'curaga', 1 });
end);

test('ninjutsu tiers are spelled Ichi, Ni and San', function()
    assert_eq({ tiers.split('Utsusemi: Ichi') }, { 'utsusemi', 1 });
    assert_eq({ tiers.split('Utsusemi: Ni') }, { 'utsusemi', 2 });
    assert_eq({ tiers.split('Katon: San') }, { 'katon', 3 });
end);

test('families are keyed case-insensitively and the display name drops the numeral', function()
    assert_eq({ tiers.split('cure iii') }, { 'cure', 3 });
    assert_eq(tiers.display('Cure III'), 'Cure');
    assert_eq(tiers.display('Utsusemi: Ni'), 'Utsusemi');
    assert_eq(tiers.display('Haste'), 'Haste');
end);
