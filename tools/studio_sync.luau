-- @copia-dos-arquivos
-- Lado Studio do tools/studio_sync.py (sincronização nos dois sentidos, sem apagar trabalho de ninguém).
-- Rodar pelo MCP (execute_luau, Edit) com o servidor ligado:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8771/studio_sync.luau", true))()
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8771/"
local MAX_SOURCE = 199999 -- o Studio recusa Source maior

local function hash(s: string): number
	s = s:gsub("\r", "")
	local x = 0
	local n = #s
	local i = 1
	while i <= n do
		local j = math.min(i + 3999, n)
		for _, c in { string.byte(s, i, j) } do
			x = (x * 31 + c) % 2147483647
		end
		i = j + 1
	end
	return x
end

local manifest = Http:JSONDecode(Http:GetAsync(BASE .. "manifest", true))

local function resolvePath(path, create: boolean): Instance?
	local node: Instance = game
	for i, name in path do
		local child = node:FindFirstChild(name)
		if not child then
			if not create then
				return nil
			end
			if i == 1 then
				child = game:GetService(name)
			else
				child = Instance.new("Folder")
				child.Name = name
				child.Parent = node
			end
		end
		node = child
	end
	return node
end

local scripts = {}
for _, rootPath in manifest.roots do
	local root = resolvePath(rootPath, false)
	if root then
		local list = root:GetDescendants()
		table.insert(list, 1, root)
		for _, d in list do
			if d:IsA("LuaSourceContainer") then
				local parts = {}
				local cur: Instance = d
				while cur ~= game do
					table.insert(parts, 1, cur.Name)
					cur = cur.Parent :: Instance
				end
				local key = table.concat(parts, "/")
				local src = (d :: any).Source
				local h = hash(src)
				local entry = { class = d.ClassName, hash = h }
				if manifest.hashes[key] ~= h then
					entry.source = src
				end
				scripts[key] = entry
			end
		end
	end
end

local plan = Http:JSONDecode(Http:PostAsync(BASE .. "plan", Http:JSONEncode({ scripts = scripts })))
if plan.error then
	error("studio_sync: " .. plan.error)
end

local ok, failed = {}, {}
for _, op in plan.ops do
	local key = table.concat(op.path, "/")
	if op.op == "write" then
		if #op.source > MAX_SOURCE then
			failed[key] = "Source grande demais para o Studio"
			continue
		end
		local parentPath = table.clone(op.path)
		local name = table.remove(parentPath)
		local parent = resolvePath(parentPath, true) :: Instance
		local inst = parent:FindFirstChild(name)
		if inst and inst.ClassName ~= op.class then
			failed[key] = "existe como " .. inst.ClassName .. ", arquivo diz " .. op.class
			continue
		end
		if not inst then
			inst = Instance.new(op.class)
			inst.Name = name
			inst.Parent = parent
		end
		local success, err = pcall(function()
			(inst :: any).Source = op.source
		end)
		if success then
			table.insert(ok, key)
		else
			failed[key] = tostring(err)
		end
	elseif op.op == "delete" then
		local inst = resolvePath(op.path, false)
		if inst then
			inst:Destroy()
		end
		table.insert(ok, key)
	end
end

local res = Http:JSONDecode(Http:PostAsync(BASE .. "ack", Http:JSONEncode({ ok = ok, failed = failed })))
return res.summary
