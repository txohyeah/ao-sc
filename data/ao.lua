

-- module: "token"
local function _loaded_mod_token()
local token = { _version = "0.0.4" }

local json = require('json')
local bint = require('.bint')(256)
local ao = require('ao')

local utils = {
  add = function(a, b)
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    return tostring(bint(a) - bint(b))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return tonumber(a)
  end
}

--[[
     Initialize State

     ao.id is equal to the Process.Id
   ]]
--
Variant = "0.0.3"

-- token should be idempotent and not change previous state updates
Denomination = Denomination or 12
Balances = Balances or {}
-- 21_000_000 AO Tokens
-- 21_000_000_000_000_000_000 Armstrongs
TotalSupply = "21000000000000000000"
Name = 'AO'
Ticker = 'AO'
Logo = Logo or 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY'


--[[
     Add handlers for each incoming Action defined by the ao Standard Token Specification
   ]]
--

--[[
     Info
   ]]
--
token.info = function(msg)
  ao.send({
    Target = msg.From,
    Name = Name,
    Ticker = Ticker,
    Logo = Logo,
    Denomination = tostring(Denomination)
  })
end


--[[
     Balance
   ]]
--
token.balance = function(msg)
  local bal = '0'

  -- If not Recipient is provided, then return the Senders balance
  if (msg.Tags.Recipient and Balances[msg.Tags.Recipient]) then
    bal = Balances[msg.Tags.Recipient]
  elseif msg.Tags.Target and Balances[msg.Tags.Target] then
    bal = Balances[msg.Tags.Target]
  elseif Balances[msg.From] then
    bal = Balances[msg.From]
  end

  ao.send({
    Target = msg.From,
    Balance = bal,
    Ticker = Ticker,
    Account = msg.Tags.Recipient or msg.From,
    Data = bal
  })
end

--[[
     Balances
   ]]
--
token.balances = function(msg)
  ao.send({ Target = msg.From, Data = Balances })
end
--[[
     Transfer
   ]]
--
token.transfer = function(msg)
  if MintCount < 100000 then
    Send({ Target = msg.From, Data = "Transfer is locked!" })
    return "Transfer is locked"
  end
  local status, err = pcall(function()
    assert(type(msg.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint(msg.Quantity) > bint(0), 'Quantity must be greater than 0')

    if not Balances[msg.From] then Balances[msg.From] = "0" end
    if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

    if bint(msg.Quantity) <= bint(Balances[msg.From]) then
      Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
      Balances[msg.Recipient] = utils.add(Balances[msg.Recipient], msg.Quantity)

      --[[
          Only send the notifications to the Sender and Recipient
          if the Cast tag is not set on the Transfer message
        ]]
      --
      if not msg.Cast then
        -- Debit-Notice message template, that is sent to the Sender of the transfer
        local debitNotice = {
          Target = msg.From,
          Action = 'Debit-Notice',
          Recipient = msg.Recipient,
          Quantity = msg.Quantity,
          Data = Colors.gray ..
              "You transferred " ..
              Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors.reset
        }
        -- Credit-Notice message template, that is sent to the Recipient of the transfer
        local creditNotice = {
          Target = msg.Recipient,
          Action = 'Credit-Notice',
          Sender = msg.From,
          Quantity = msg.Quantity,
          Data = Colors.gray ..
              "You received " ..
              Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
        }

        -- Add forwarded tags to the credit and debit notice messages
        for tagName, tagValue in pairs(msg) do
          -- Tags beginning with "X-" are forwarded
          if string.sub(tagName, 1, 2) == "X-" then
            debitNotice[tagName] = tagValue
            creditNotice[tagName] = tagValue
          end
        end

        -- Send Debit-Notice and Credit-Notice
        ao.send(debitNotice)
        ao.send(creditNotice)
      end
    else
      ao.send({
        Target = msg.From,
        Action = 'Transfer-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!'
      })
    end
  end)
  if err then
    Send({ Target = msg.From, Data = err })
    return err
  end
  return "OK"
end

--[[
     Total Supply
   ]]
--
token.totalSupply = function(msg)
  assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')

  ao.send({
    Target = msg.From,
    Action = 'Total-Supply',
    Data = TotalSupply,
    Ticker = Ticker
  })
end

--[[
 Burn
]] --
token.burn = function(msg)
  assert(type(msg.Quantity) == 'string', 'Quantity is required!')
  assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')

  Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
  TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

  ao.send({
    Target = msg.From,
    Data = Colors.gray .. "Successfully burned " .. Colors.blue .. msg.Quantity .. Colors.reset
  })
end


return token

end

_G.package.loaded["token"] = _loaded_mod_token()

-- module: "allocator"
local function _loaded_mod_allocator()
  local allocator = { _version = "0.0.1" }

local bint = require('.bint')(256)

-- utility functions
local function reduce(func, initial, t)
    local result = initial
    for _, v in ipairs(t) do
        result = func(result, v)
    end
    return result
end

local function values(t)
    local result = {}
    for _, v in pairs(t) do
        table.insert(result, v)
    end
    return result
end

local function keys(t)
    local result = {}
    for k, _ in pairs(t) do
        table.insert(result, k)
    end
    return result
end

local function sum(t)
    return reduce(function(a, b) return a + b end, 0, t)
end

local function mergeAll(tables)
    local result = {}
    for _, t in ipairs(tables) do
        for k, v in pairs(t) do
            result[k] = v
        end
    end
    return result
end


function allocator.allocate(balances, reward)
    local function add(a, b) return bint(a) + bint(b) end

    -- Calculate total positive balances
    local total = reduce(add, bint(0), values(balances))
    
    -- Allocate rewards based on balances
    local allocation = mergeAll(
        reduce(function(a, s)
            local asset = s[1]
            local balance = bint(s[2])
            
            if balance < bint(1) then
                return a
            end
            
            local pct = (balance / total) * bint(100)
            local coins = math.floor(bint(reward) * (pct / bint(100)) + (bint(1) / bint(2))) -- Round to nearest integer
            
            table.insert(a, {[asset] = tostring(coins)})
            return a
        end, {}, (function()
            local result = {}
            for k, v in pairs(balances) do
                table.insert(result, {k, v})
            end
            return result
        end)())
    )
    
    -- Handle off by one errors
    local remainder = reward - sum(values(allocation))
    local k = keys(allocation)
    local i = 1
    while remainder > 0 do
        allocation[k[i]] = allocation[k[i]] + 1
        remainder = remainder - 1
        i = (i % #k) + 1
    end
    
    return allocation
end

return allocator

end

_G.package.loaded["allocator"] = _loaded_mod_allocator()

-- module: "mint"
local function _loaded_mod_mint()
--[[
  Mint Module handles the minting functions for AO Token

]]
local bint = require('.bint')(256)
local sqlite3 = require('lsqlite3')
local Allocator = require('allocator')

local allocate = Allocator.allocate
MintCount = MintCount or 0
MintDb = MintDb or sqlite3.open_memory()
local INSERT_ORACLE_SQL = "INSERT INTO Oracles (Oracle, Name, StartTimestamp, DelayDepositInterval) VALUES (?, ?, ?, ?)"
-- DbAdmin Module is required
dbAdmin = dbAdmin or require('@rakis/DbAdmin').new(MintDb)
-- processes or wallets allowed to send event batches
BatchesAllowed = BatchesAllowed or
    { "88T4YtovZ9ZDgEh1Xb0T_VlF9rXCRFOdi_B2Eyv1eMs", "w7PAoAtLRjE48eW1qoKt5n5rzCyeOxDTt6RbYwELxDU" }
LastMintHeight = LastMintHeight or "1443785"
Rewards = {}

local utils = {
  add = function(a, b)
    if (bint(a) < bint(0)) then
      a = 0
    end
    if (bint(b) < bint(0)) then
      b = 0
    end
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    if bint(b) < bint(0) then
      b = 0
    end
    local value = bint(a) - bint(b)
    if value < bint(0) then
      return "0"
    else
      return tostring(bint(a) - bint(b))
    end
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return tonumber(a)
  end,
  greaterThan = function(a, b)
    return bint(a) > bint(b)
  end
}

local mint = { _version = "0.0.1" }

-- local db functions
local function insertOracle(oracle, name, startTimestamp, delayDepositInterval)
  local stmt = MintDb:prepare(INSERT_ORACLE_SQL)

  if stmt == nil then
    error("Failed to prepare statement: " .. MintDb:errmsg())
  end

  stmt:bind_values(oracle, name, startTimestamp, delayDepositInterval)

  local result = stmt:step()
  if result ~= sqlite3.DONE then
    error("Failed to insert record: " .. MintDb:errmsg())
  end

  stmt:finalize()
end

local function insertDeposit(recipient, oracle, user, token, amount, updated)
  -- Prepare the SQL select statement to check if the record exists
  local select_stmt = MintDb:prepare("SELECT Amount FROM Rewards WHERE Recipient = ? AND Token = ?")
  select_stmt:bind_values(recipient, token)
  local result = select_stmt:step()

  print(string.format("Adding Deposit to %s in the amount of %s for Token %s", recipient, amount, token))
  local rewardAccountExists = false
  local current_amount = 0
  if result == sqlite3.ROW then
    rewardAccountExists = true
    current_amount = bint(select_stmt:get_value(0))
  end
  select_stmt:finalize()

  print(string.format("Current Amount %s", current_amount))
  --error("Current: " .. current_amount .. " amount: " .. amount)
  -- Calculate the new total amount
  local total_amount = utils.add(current_amount, amount)

  print(string.format("Total Amount %s", total_amount))
  if rewardAccountExists then
    -- print("Adding Deposit")
    -- Prepare the SQL update statement to update the existing record
    local update_stmt = MintDb:prepare("UPDATE Rewards SET Amount = ?, Updated = ? WHERE Recipient = ?")
    update_stmt:bind_values(total_amount, updated, recipient)
    local update_result = update_stmt:step()
    if update_result ~= sqlite3.DONE then
      print("Failed to update record: " .. MintDb:errmsg())
    end
    update_stmt:finalize()
    -- print("Finish Update")
  else
    -- print("Insert Deposit")
    -- Prepare the SQL insert statement to insert a new record
    local insert_stmt = MintDb:prepare(
      "INSERT INTO Rewards (Recipient, Oracle, User, Token, Amount, Updated) VALUES (?, ?, ?, ?, ?, ?)")
    insert_stmt:bind_values(recipient, oracle, user, token, total_amount, updated)
    local insert_result = insert_stmt:step()
    if insert_result ~= sqlite3.DONE then
      print("Failed to insert record: " .. MintDb:errmsg())
    end
    insert_stmt:finalize()
    -- print("Finish Deposit")
  end
end

local function updateWithdraw(user, amount, updated)
  -- Prepare the SQL select statement to check if the record exists
  local select_stmt = MintDb:prepare("SELECT Amount FROM Rewards WHERE Recipient = ? and Token = ?")
  select_stmt:bind_values(user, "AR")
  local result = select_stmt:step()

  local current_amount = 0
  if result == sqlite3.ROW then
    current_amount = bint(select_stmt:get_value(0))
  end
  select_stmt:finalize()

  -- Calculate the new total amount
  local total_amount = utils.subtract(current_amount, amount)
  print(string.format("Withdraw from %s in the amount of %s leaves %s", user, amount, total_amount))
  if current_amount > 0 then
    -- print("Updating Withdraw")
    -- Prepare the SQL update statement to update the existing record
    local update_stmt = MintDb:prepare("UPDATE Rewards SET Amount = ?, Updated = ? WHERE User = ?")
    update_stmt:bind_values(total_amount, updated, user)
    local update_result = update_stmt:step()
    if update_result ~= sqlite3.DONE then
      print("Failed to update record: " .. MintDb:errmsg())
    end
    update_stmt:finalize()
    -- print("Finish Update")
  end
end

-- init database
function mint.init()
  MintDb:exec [[
CREATE TABLE IF NOT EXISTS Oracles (
  Oracle TEXT PRIMARY KEY,
  Name TEXT NOT NULL,
  StartTimestamp TEXT NOT NULL,
  DelayDepositInterval TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS Rewards (
  Recipient TEXT NOT NULL,
  Token TEXT NOT NULL,
  Oracle TEXT NOT NULL,
  User TEXT NOT NULL,
  Amount TEXT NOT NULL,
  Updated TEXT NOT NULL,
  PRIMARY KEY (Recipient, Token),
  FOREIGN KEY (Oracle) REFERENCES Oracles(Oracle)
);
  ]]
  return "Mint Initialized."
end

function mint.isOracle(msg)
  if not Utils.includes(msg.Owner, ao.authorities) then
    return false
  end
  local oracle = msg.From

  local stmt = MintDb:prepare("SELECT 1 FROM Oracles WHERE Oracle = ?")
  stmt:bind_values(oracle)
  stmt:step()
  local exists = (stmt:get_value(0) ~= nil)
  stmt:finalize()
  return exists
end

-- handle register Oracle
function mint.registerOracle(msg)
  local status, err = pcall(function()
    assert(type(msg.Oracle) == "string", "Oracle is required!")
    assert(type(msg.Name) == "string", "Name is required!")
    assert(type(msg.Start) == "string", "Start Timestamp required!")
    assert(type(msg.DepositDelay) == "string", "Deposit Delay is required")
    insertOracle(msg.Oracle, msg.Name, msg.Start, msg.DepositDelay)
    Send({ Target = msg.From, Data = "registered." })
  end)
  if err then
    print(err)
    return err
  end
  return "OK"
end

-- handle Oracle Deposit request
function mint.handleDeposit(msg)
  local status, err = pcall(function()
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.User) == "string", "User is required!")
    assert(type(msg.Token) == "string", "Token is required!")
    assert(type(msg.TokenAmount) == "string", "TokenAmount is required!")
    assert(type(msg.Reward) == "string", "Reward is required!")
    assert(type(msg.TransactionHash) == "string", "TransactionHash is required!")
    -- assert(type(msg.Tags.Timestamp) == "string", "Timestamp is required!")
    insertDeposit(msg.Recipient, msg.From, msg.User, msg.Token, msg.TokenAmount, msg.Timestamp)
    Send({ Target = msg.From, Action = "Deposit-Notice", Data = msg.TokenAmount .. "-" .. msg.Token })
    if msg.User ~= msg.Recipient then
      Send({ Target = msg.Recipient, Action = "Deposit-Notice", Data = msg.TokenAmount .. "-" .. msg.Token })
    end
  end)
  if err then
    Send({ Target = msg.From, Data = err })
    return err
  end
  return "OK"
end

-- handle Oracle Withdraw request
function mint.handleWithdraw(msg)
  local status, err = pcall(function()
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.User) == "string", "User is required!")
    assert(type(msg.Token) == "string", "Token is required!")
    assert(type(msg.TokenAmount) == "string", "TokenAmount is required!")
    assert(type(msg.Reward) == "string", "Reward is required!")
    assert(type(msg.TransactionHash) == "string", "TransactionHash is required!")
    -- assert(type(msg.Tags.Timestamp) == "string", "Timestamp is required!")
    updateWithdraw(msg.Recipient, msg.TokenAmount, msg.Timestamp)
    Send({ Target = msg.From, Action = "Withdraw-Notice", Data = msg.TokenAmount .. "-" .. msg.Token })
    if msg.User ~= msg.Recipient then
      Send({ Target = msg.Recipient, Action = "Withdraw-Notice", Data = msg.TokenAmount .. "-" .. msg.Token })
    end
  end)
  if err then
    Send({ Target = msg.From, Data = err })
    return err
  end
  return "OK"
end

-- handle Oracle OverPlus reward distribution
function mint.handleOverPlus(msg)
  -- TODO:
end

local function split_by_linefeed(str)
  local result = {}
  for line in str:gmatch("[^\r\n]+") do
    table.insert(result, line)
  end
  return result
end

local function split_by_comma(str)
  local result = {}
  for line in str:gmatch("[^,]+") do
    table.insert(result, line)
  end
  return result
end

-- Handle Batch Deposits mainly for loading WalletList
function mint.Batch(msg)
  local status, err = pcall(function()
    if msg.Height and LastMintHeight >= msg.Height then
      print("Already Applied Block: " .. msg.Height)
      return "OK"
    end
    assert(type(msg.Token) == "string", "Token is required!")
    -- Batch can be in two formats
    -- 1. Address:Balance KeyValue
    -- 2. Mint Event Transactions "Format = 'Event-List'"
    if msg.Format and msg.Format == "Event-List" then
      print('Format: ' .. msg.Format)
      -- event list
      local events = require('json').decode(msg.Data)
      print(string.format("Received %d events to process", #events))
      for i = 1, #events do
        local event = events[i]
        if event.Action == "Deposit" then
          print(string.format('Deposited %s for %s', event.TokenAmount, event.Recipient))
          insertDeposit(event.Recipient, msg.From, event.User, event.Token, event.TokenAmount, msg.Timestamp)
        elseif event.Action == "Withdraw" then
          local total = utils.add(event.TokenAmount, event.Fee or "0")
          print(string.format("Withdraw %s for %s", total, event.User))
          updateWithdraw(event.User, total, event.Timestamp)
        end
      end
    elseif msg.Format and msg.Format == "Event-List-CSV" then
      local lines = split_by_linefeed(msg.Data)
      for i = 1, #lines do
        local fields = split_by_comma(lines[i])
        local event = {
          Action = fields[1],
          Recipient = fields[2],
          Reward = fields[3],
          Fee = fields[4],
          Timestamp = fields[5]
        }
        if event.Action == "Deposit" then
          insertDeposit(event.Recipient, msg.From, event.Recipient, "AR", event.Reward, event.Timestamp)
        elseif event.Action == "Withdraw" then
          local total = utils.add(event.Reward or "0", event.Fee or "0")
          updateWithdraw(event.Recipient, total, event.Timestamp)
        end
        -- print('Processed: ' .. lines[i])
      end
      return #lines
    else
      -- do key/value
      local deposits = require('json').decode(msg.Data)
      for k, v in pairs(deposits) do
        print('insert deposit: ' .. v .. ' to ' .. k)
        insertDeposit(k, msg.From, k, msg.Token, v, msg.Timestamp)
        Send({ Target = k, Action = "Deposit-Notice", Data = v .. "-" .. msg.Token })
      end
    end
  end)
  if err then
    Send({ Target = msg.From, Data = err })
    return err
  end
  return "OK"
end

function mint.LoadBalances(msg)
  local status, err = pcall(function()
    local deposits = require('json').decode(msg.Data)
    for k, v in pairs(deposits) do
      print('initialize balance: ' .. v .. ' to ' .. k)
      Balances[k] = v
    end
  end)
  if err then
    Send({ Target = msg.From, Data = err })
    return err
  end
  return "OK"
end

-- handle Mint
function mint.Mint(msg)
  if msg.Action == "Cron" and MODE == "OFF" then
    print("Not Minting by CRON untils MODE is set to ON")
    return "OK"
  end

  print('Minting Every 5 minutes!')
  -- Get Reward List
  local list = Utils.reduce(
    function(acc, item)
      acc[item.Recipient] = item.Amount
      return acc
    end,
    {},
    dbAdmin:exec [[select Recipient, Amount from Rewards;]]
  )
  -- Get Remaining Supply
  local remainingSupply = utils.subtract(TotalSupply, MintedSupply)
  -- Get Reward Percent
  local reward = string.format('%.0f', bint(remainingSupply) * ARM_Mint_PCT)
  -- Allocate Rewards
  local rewards = allocate(list, reward)
  local supply = "0"
  -- Update Balances
  for k, v in pairs(rewards) do
    if not Balances[k] then
      Balances[k] = "0"
    end
    Balances[k] = utils.add(Balances[k], v)
    -- print("Address: " .. k .. " Balance " .. Balances[k])
    supply = utils.add(supply, Balances[k])
  end
  -- Calculate Circulating Supply
  MintedSupply = supply
  Send({ Target = msg.From, Data = "Minted AO Token Rewards" })
  LastMintTimestamp = msg.Timestamp
  MintCount = MintCount + 1
  return "ok"
end

-- matchers
function mint.isRegister(msg)
  return ao.id == msg.From and ao.isTrusted(msg) and msg.Action == "Oracle.Register"
end

function mint.isDeposit(msg)
  return msg.Action == "Deposit" and mint.isOracle(msg)
end

function mint.isWithdraw(msg)
  return msg.Action == "Withdraw" and mint.isOracle(msg)
end

function mint.isOverPlus(msg)
  return msg.Action == "OverPlus" and mint.isOracle(msg)
end

function mint.isBatch(msg)
  -- return msg.Action == "Mint.Batch" and MODE == "OFF" and msg.Owner == "w7PAoAtLRjE48eW1qoKt5n5rzCyeOxDTt6RbYwELxDU"
  return msg.Action == "Mint.Batch" and Utils.includes(msg.From, BatchesAllowed)
end

function mint.isLoadBalances(msg)
  return msg.Action == "Mint.LoadBalances" and Utils.includes(msg.From, BatchesAllowed)
end

function mint.isCron(msg)
  return msg.Action == "Cron" and msg.From == "gCpQfnG6nWLlKs8jYgV8oUfe38GYrPLv59AC7LCtCGg"
end

return mint

end

_G.package.loaded["mint"] = _loaded_mod_mint()

--[[
  AO Token uses the local token contract
]]
local token = require('token')
local bint = require('.bint')(256)

-- LastMintTimestamp
LastMintTimestamp = LastMintTimestamp or 0
-- MODE - OFF = Manual Minting only, ON = Automated Minting
MODE = MODE or "OFF"

-- Circulating Supply
MintedSupply = MintedSupply or "0"
-- 5 MIN REWARD SUPPLY PERCENT
AR_Mint_PCT = bint("1647321875") / bint("1000")
ARM_Mint_PCT = AR_Mint_PCT / bint("1000000000000")

Mint = require('mint')

Handlers.add('mint.register', Mint.isRegister, Mint.registerOracle)
Handlers.add('mint.deposit', Mint.isDeposit, Mint.handleDeposit)
Handlers.add('mint.withdraw', Mint.isWithdraw, Mint.handleWithdraw)

Handlers.add('cron.mint', Mint.isCron, Mint.Mint)
Handlers.add('mint.batch', Mint.isBatch, Mint.Batch)
Handlers.add('mint.loadbalances', Mint.isLoadBalances, Mint.LoadBalances)

Handlers.add('token.info',
  Handlers.utils.hasMatchingTag("Action", "Info"),
  token.info
)

Handlers.add('token.balance',
  Handlers.utils.hasMatchingTag("Action", "Balance"),
  token.balance
)

Handlers.add('token.balances',
  Handlers.utils.hasMatchingTag("Action", "Balances"),
  token.balances
)

Handlers.add('token.transfer',
  Handlers.utils.hasMatchingTag("Action", "Transfer"),
  token.transfer
)

Handlers.add('token.totalSupply',
  Handlers.utils.hasMatchingTag("Action", "Total-Supply"),
  token.totalSupply
)

Handlers.add('token.burn',
  Handlers.utils.hasMatchingTag("Action", "Burn"),
  token.burn
)

Handlers.add('token.mintedSupply',
  Handlers.utils.hasMatchingTag("Action", "Minted-Supply"),
  function(msg)
    Send({ Target = msg.From, Data = MintedSupply })
    print("Id: " .. msg.From .. " Requested Minted Supply: " .. MintedSupply)
  end
)

-- need to create this in aos
--[[
Need to implement this in aos to always run this handler no matter what at the end.

Handlers.always('mint.automatic', function (msg)
  local Now = msg.Timestamp
  if MODE == "ON" then
     if Now > LastMintTimestamp + FIVE_MINUTES and Now < LastMintTimestamp + TEN_MINUTES then
       Mint
     end
     Mint.Mint(msg)
     return "ok"
  end

end)
]]

return 2
