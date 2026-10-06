local cost = require('lib.cost');

test('a second of frames folds into a mean and a worst, held while the next second counts', function()
    local c = cost.new(0);
    c = cost.add(c, 0.002, 0.5);
    c = cost.add(c, 0.004, 1.0);
    assert_eq(cost.text(c), '3.00 ms/frame, worst 4.0 ms');
    assert_eq(cost.heavy(c), true, 'over the 2 ms budget');
    c = cost.add(c, 0.0001, 1.5);
    assert_eq(cost.text(c), '3.00 ms/frame, worst 4.0 ms', 'last second shown until this one is up');
    c = cost.add(c, 0.0001, 2.0);
    assert_eq(cost.text(c), '0.10 ms/frame, worst 0.1 ms');
    assert_eq(cost.heavy(c), false);
end);

test('nothing is shown before the first second is up', function()
    assert_eq(cost.text(cost.new(0)), '0.00 ms/frame, worst 0.0 ms');
    assert_eq(cost.heavy(cost.new(0)), false);
end);
