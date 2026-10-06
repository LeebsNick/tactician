local command = require('lib.command');

test('each action kind becomes the slash command a player would type', function()
    assert_eq(command.text({ kind = 'ma', name = 'Cure III', token = '<p1>' }), '/ma "Cure III" <p1>');
    assert_eq(command.text({ kind = 'ja', name = 'Divine Seal', token = '<me>' }), '/ja "Divine Seal" <me>');
    assert_eq(command.text({ kind = 'ws', name = 'Fast Blade', token = '<t>' }), '/ws "Fast Blade" <t>');
    assert_eq(command.text({ kind = 'rattack', token = '<t>' }), '/ra <t>');
    assert_eq(command.text({ kind = 'item', name = 'Hi-Potion', token = '<me>' }), '/item "Hi-Potion" <me>');
end);
