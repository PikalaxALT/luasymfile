--  Symfile Library
--  Unlicensed

symfile = {symbols = {}}

DOMAIN_ROM = 0
DOMAIN_VRAM = 1
DOMAIN_SRAM = 2
DOMAIN_WRAM = 3

function ba2gbaddr (bank, addr)
  --  Returns the offset of the given address and the appropriate memory domain in BizHawk.
  --  Main IO Bus is not included in this, as that is just "addr".
  --  Valid domains are ROM, VRAM, SRAM, and WRAM.
  --  The appropriate domain is automatically detected if possible.
  local domain
  if addr < 0x8000 then
    addr = bit.band(addr, 0x3FFF)
    bank = bit.lshift(bank, 14)
    domain = DOMAIN_ROM
  elseif addr < 0xC000
    addr = bit.band(addr, 0x1FFF)
    bank = bit.lshift(bank, 13)
    if addr < 0xA000 then domain = DOMAIN_VRAM else domain = DOMAIN_SRAM end
  elseif addr < 0xE000
    addr = bit.band(addr, 0x0FFF)
    bank = bit.lshift(bank, 12)
    domain = DOMAIN_WRAM
  else
    error("invalid memory domain")
  end
  return bit.bor(bank, addr), domain
end

function gbaddr2ba (gbaddr, domain)
  --  Returns the bank and address of the given offset in the given BizHawk memory domain.
  --  domain is either DOMAIN_ROM, DOMAIN_VRAM, DOMAIN_SRAM, or DOMAIN_WRAM.
  --  These constants must be used to ensure forwards and backwards compatibility of the library.
  local bank, addr
  if domain == DOMAIN_ROM then
    addr = bit.band(gbaddr, 0x3FFF)
    bank = bit.rshift(gbaddr, 14)
    if bank ~= 0 then addr = bit.bor(addr, 0x4000) end
  elseif domain == DOMAIN_VRAM then
    addr = bit.bor(bit.band(gbaddr, 0x1FFF), 0x8000)
    bank = bit.rshift(gbaddr, 13)
  elseif domain == DOMAIN_SRAM then
    addr = bit.bor(bit.band(gbaddr, 0x1FFF), 0xA000)
    bank = bit.rshift(gbaddr, 13)
  elseif domain == DOMAIN_WRAM then
    addr = bit.bor(bit.band(gbaddr, 0x0FFF), 0xC000)
    bank = bit.rshift(gbaddr, 12)
  else
    error("invalid memory domain")
  end
  return bank, addr
end

function symfile.clear ()
  --  Destroys any loaded symbols.
  symfile.symbols = {}
end

function symfile.read (fname)
  --  Reads the symfile at fname, overwriting any previously-loaded symfile.
  symfile.clear()
  for local line in io.lines(fname) do
    local bank, addr, name = string.match(line, "(%x+):(%x+) (%g+)")
    symfile.symbols[name] = {tonumber(bank, 16), tonumber(addr, 16)}
  end
end

function symfile.get_name_from_ba (bank, addr)
  --  Gets the name of a symbol at the given bank and addr.
  --  If no such symbol is found, returns nil.
  --  If multiple symbols share the same bank-addr combination, returns the first symbol found.
  for local name, ba in pairs(symfile.symbols) do
    if ba[1] == bank and ba[2] == addr then return name end
  end
end

function symfile.get_name_from_gbaddr (gbaddr, domain)
  --  Gets the name of a symbol at the given offset and memory domain.
  --  If no such symbol is found, returns nil.
  --  If multiple symbols share the same bank-addr combination, returns the first symbol found.
  local bank, addr = gbaddr2ba(gbaddr, domain)
  return symfile.get_name_from_ba(bank, addr)
end

function symfile.get_ba_from_name (name)
  --  Gets the bank and addr associated with the given symbol name.
  --  If no such symbol is found, returns nil.
  for local cname, ba in pairs(symfile.symbols) do
    if cname == name then return ba[1], ba[2] end
  end
  return nil, nil
end

function symfile.get_gbaddr_from_name (name)
  --  Gets the bank and addr associated with the given symbol name.
  --  If no such symbol is found, returns nil.
  local bank, addr = symfile.get_ba_from_name (name)
  if bank ~= nil then return ba2gbaddr(bank, addr) end
  return nil, nil
end
