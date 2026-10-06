local client = require('lib.client');
local F      = dofile('tactician/tests/fixtures.lua');

-- Plain tables with the Ashita method names the module reads.
local function fake()
    local members = {
        [0] = { active = 1, zone = 100, idx = 0x400, id = 100, name = 'Me',   hpp = 80, mpp = 60, tp = 1200, hp = 800, mp = 300, job = 3, lvl = 41 },
        [1] = { active = 1, zone = 100, idx = 0x401, id = 101, name = 'Tank', hpp = 45, mpp = 70, tp = 300,  hp = 500, mp = 100, job = 7, lvl = 41 },
        [2] = { active = 1, zone = 101, idx = 0x402, id = 102, name = 'Away', hpp = 99, mpp = 99, tp = 0,    hp = 1,   mp = 1,   job = 4, lvl = 40 },
        [3] = { active = 0, zone = 100, idx = 0,     id = 0,   name = '',     hpp = 0,  mpp = 0,  tp = 0,    hp = 0,   mp = 0,   job = 0, lvl = 0 },
    };
    for i = 4, 5 do members[i] = members[3]; end
    local party = {};
    function party.GetMemberIsActive(_, i) return members[i].active; end
    function party.GetMemberZone(_, i) return members[i].zone; end
    function party.GetMemberTargetIndex(_, i) return members[i].idx; end
    function party.GetMemberServerId(_, i) return members[i].id; end
    function party.GetMemberName(_, i) return members[i].name; end
    function party.GetMemberHPPercent(_, i) return members[i].hpp; end
    function party.GetMemberMPPercent(_, i) return members[i].mpp; end
    function party.GetMemberTP(_, i) return members[i].tp; end
    function party.GetMemberHP(_, i) return members[i].hp; end
    function party.GetMemberMP(_, i) return members[i].mp; end
    function party.GetMemberMainJob(_, i) return members[i].job; end
    function party.GetMemberMainJobLevel(_, i) return members[i].lvl; end

    local player = { buffs = { 40, 33, 0, 255 } };
    for i = #player.buffs + 1, 32 do player.buffs[i] = 255; end
    function player.GetHPMax(_) return 1000; end
    function player.GetMainJob(_) return 3; end
    function player.GetMainJobLevel(_) return 41; end
    function player.GetSubJob(_) return 4; end
    function player.GetSubJobLevel(_) return 20; end
    function player.GetBuffs(self) return self.buffs; end
    function player.GetPetTP(_) return 900; end
    function player.GetPetMPPercent(_) return 80; end
    function player.GetIsZoning(_) return 0; end
    function player.HasSpell(_, id) return id == 1 or id == 3; end
    function player.HasAbility(_, id) return id == 528; end
    function player.HasWeaponSkill(_, id) return id == 32; end

    local ents = {
        [0x400] = { status = 1, hpp = 80, name = 'Me', flags = 0x0D, pet = 0x20, pos = { 1, 2, 3 } },
        [0x401] = { status = 0, hpp = 45, name = 'Tank', flags = 0x0D, pet = 0, pos = { 10, 20, 30 } },
        [0x10]  = { status = 1, hpp = 70, name = 'Goblin_Thug', flags = 0x10, pet = 0 },
        [0x11]  = { status = 0, hpp = 100, name = 'Shop_Keeper', flags = 0x02, pet = 0 },
        [0x20]  = { status = 1, hpp = 55, name = 'Carbuncle', flags = 0x100, pet = 0 },
    };
    local entity = {};
    function entity.GetStatus(_, i) return ents[i].status; end
    function entity.GetHPPercent(_, i) return ents[i].hpp; end
    function entity.GetName(_, i) return ents[i].name; end
    function entity.GetSpawnFlags(_, i) return ents[i].flags; end
    function entity.GetPetTargetIndex(_, i) return ents[i].pet; end
    function entity.GetLocalPositionX(_, i) return (ents[i].pos or {})[1]; end
    function entity.GetLocalPositionY(_, i) return (ents[i].pos or {})[2]; end
    function entity.GetLocalPositionZ(_, i) return (ents[i].pos or {})[3]; end
    function entity.GetServerId(_, i) return i == 0x10 and 500 or (i == 0x20 and 200 or 0); end

    local target = { idx = 0x10 };
    function target.GetTargetIndex(self) return self.idx; end

    local recast = { spells = { [3] = 300 }, slots = { [0] = { id = 0, timer = 0 }, [1] = { id = 13, timer = 1800 } } };
    function recast.GetSpellTimer(self, id) return self.spells[id] or 0; end
    function recast.GetAbilityTimerId(self, x) return (self.slots[x] or { id = 0 }).id; end
    function recast.GetAbilityTimer(self, x) return (self.slots[x] or { timer = 0 }).timer; end

    local inventory = { bags = { [0] = { { Id = 4116, Count = 2 }, { Id = 0, Count = 0 }, { Id = 4116, Count = 1 } }, [3] = { { Id = 4112, Count = 1 } } } };
    function inventory.GetContainerCountMax(self, bag) return #(self.bags[bag] or {}); end
    function inventory.GetContainerItem(self, bag, i) return self.bags[bag][i]; end

    return { party = party, player = player, entity = entity, target = target, recast = recast, inventory = inventory }, ents, target;
end

test('me carries my readings, status word and statuses as a set', function()
    local mm = fake();
    local me = client.me(mm);
    assert_eq(me.id, 100);
    assert_eq(me.idx, 0x400);
    assert_eq(me.hp, 800);
    assert_eq(me.hpmax, 1000);
    assert_eq(me.mp, 300);
    assert_eq(me.buffs, { [40] = true, [33] = true });
    assert_eq(me.status, 'engaged');
    assert_eq(me.pos, { x = 1, y = 2, z = 3 });
    assert_eq(me.job, 3);
    assert_eq(me.sublevel, 20);
end);

test('party is the active members in my zone, by slot, with their statuses when known', function()
    local mm = fake();
    local party = client.party(mm, { [101] = { [40] = true } });
    assert_eq(#party, 1, 'the member in another zone and the empty slots are left out');
    assert_eq(party[1].slot, 1);
    assert_eq(party[1].name, 'Tank');
    assert_eq(party[1].buffs, { [40] = true });
    assert_eq(party[1].job, 7);
    assert_eq(party[1].status, 'idle');
    assert_eq(party[1].pos, { x = 10, y = 20, z = 30 });
    assert_eq(client.party(mm, {})[1].buffs, nil, 'no status list means unknown, not empty');
end);

test('target is the targeted monster, with what the tracker says it is doing', function()
    local mm, _, target = fake();
    local tg = client.target(mm, { casting = true, readying = false });
    assert_eq(tg, { id = 500, idx = 0x10, name = 'Goblin Thug', hpp = 70, casting = true, readying = false });
    target.idx = 0x11;
    assert_eq(client.target(mm, {}), nil, 'an NPC is not a target to fight');
    target.idx = 0;
    assert_eq(client.target(mm, {}), nil);
end);

test('pet comes off my entity, with TP and MP from the player block', function()
    local mm, ents = fake();
    assert_eq(client.pet(mm, 0x400), { id = 200, idx = 0x20, name = 'Carbuncle', hpp = 55, mpp = 80, tp = 900 });
    ents[0x400].pet = 0;
    assert_eq(client.pet(mm, 0x400), nil);
end);

test('recasts are seconds left, listed only while running', function()
    local mm = fake();
    local rc = client.recasts(mm, { 1, 3 });
    assert_eq(rc.spell, { [3] = 5 });
    assert_eq(rc.ability, { [13] = 30 });
end);

test('items are counted across the inventory and temporary bags', function()
    assert_eq(client.items(fake()), { [4116] = 3, [4112] = 1 });
end);

test('known lists what the player has learned out of the catalog', function()
    local known = client.known(fake(), F.catalog());
    assert_eq(known.spell, { [1] = true, [3] = true });
    assert_eq(known.ability, { [528] = true });
    assert_eq(known.ws, { [32] = true });
end);

test('party statuses decode from the five 48-byte blocks the client keeps', function()
    -- member 0: server id 101, statuses 40 and 289 (a high-bit id), then end marker 255
    local mem = {};
    local function write32(addr, v) for i = 0, 3 do mem[addr + i] = math.floor(v / 2 ^ (8 * i)) % 256; end end
    local base = 0x1000;
    write32(base, 101);
    mem[base + 16] = 40;  mem[base + 17] = 289 % 256; mem[base + 18] = 255;
    mem[base + 8] = bit.lshift(math.floor(289 / 256), 2); -- high bits of slot 1 sit at bits 2-3 of byte 8
    write32(base + 0x30, 0);
    local function read8(a) return mem[a] or 0; end
    local function read32(a) return (mem[a] or 0) + (mem[a + 1] or 0) * 256 + (mem[a + 2] or 0) * 65536 + (mem[a + 3] or 0) * 16777216; end
    assert_eq(client.party_buffs(read8, read32, base), { [101] = { [40] = true, [289] = true } });
end);

test('the whole snapshot composes the readings', function()
    local mm = fake();
    local snap = client.snapshot(mm, F.catalog(), { now = 55, party_buffs = { [101] = {} }, tracker = { casting = false, readying = false } });
    assert_eq(snap.now, 55);
    assert_eq(snap.me.name, 'Me');
    assert_eq(#snap.party, 1);
    assert_eq(snap.target.name, 'Goblin Thug');
    assert_eq(snap.pet.name, 'Carbuncle');
    assert_eq(snap.recast.spell, { [3] = 5 });
    assert_eq(snap.items[4116], 3);
    assert_eq(snap.known.ws[32], true);
end);
