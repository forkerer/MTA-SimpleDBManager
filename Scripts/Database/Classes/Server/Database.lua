-- ----------------------------------------------------------------------------
-- Kamil Marciniak <github.com/forkerer> wrote this code. As long as you retain this 
-- notice, you can do whatever you want with this stuff. If we
-- meet someday, and you think this stuff is worth it, you can
-- buy me a beer in return.
-- ----------------------------------------------------------------------------

Database = {}
Database.metatable = {
    __index = Database,
}
setmetatable( Database, { __call = function(self,...) return self:Get(...) end } )

function Database:Get()
    if not self.instance then
        self.instance = self:New()
    end
    return self.instance
end

function Database:New()
	local instance = setmetatable( {}, Database.metatable )

	instance.host = nil
	instance.username = nil
	instance.password = nil
	instance.dbName = nil
	instance.port = nil
	instance.charset = "utf8"
	instance.connection = nil

	instance.options = {
		share = 0,
		batch = 1,
		autoreconnect = 1,
		log = 1,
		tag = "script",
		suppress = nil,
		multi_statements = 0,
	}

	instance.curAsyncQueryID = 1
	instance.asyncQueryTable = {}

	instance.dbTablesData = {}

	return instance
end

function Database:SetConnectionDetails(dbName, host, port, username, password)
	if dbName then
		self.dbName = dbName
	end
	if host then
		self.host = host
	end
	if port then
		self.port = port
	end
	if username then
		 self.username = username
	end
	if password then
		self.password = password
	end
end

function Database:SetDBName(name)
	self.dbName = name
end

function Database:SetHost(host)
	self.host = host
end

function Database:SetPort(port)
	self.port = port
end

function Database:SetUsername(username)
	self.username = username
end

function Database:SetPassword(pass)
	self.password = pass
end

function Database:SetCharset(charset)
	self.charset = charset
end

function Database:GetDBName()
	return self.dbName
end

function Database:GetHost()
	return self.host
end

function Database:GetPort()
	return self.port
end

function Database:GetUsername()
	return self.username
end

function Database:GetPassword()
	return self.password
end

function Database:GetCharset()
	return self.charset
end

function Database:SetOption(option, value)
	self.options[option] = value
end

function Database:GetOption(option)
	return self.options[option]
end

function Database:CheckConnectionDetailsValidity()
	return self.dbName and self.host
end

function Database:GenerateConnectionOptions()
	local optionsString
	if self.options and (type(self.options) == "table") then
		optionsString = ""

		-- Concat all options to string
		for name,value in pairs(self.options) do
			if value then
				optionsString = optionsString .. name .. "=" .. value .. ";"
			end
		end
	end
	return optionsString
end

function Database:GenerateHostString()
	local hostString = ""
	hostString = hostString .. "dbname=" .. self.dbName .. ";"
	hostString = hostString .. "host=" .. self.host .. ";"
	if self.port then
		hostString = hostString .. "port=" .. self.port .. ";"
	end
	if self.charset then
		hostString = hostString .. "charset=" .. self.charset .. ";"
	end
	return hostString
end

function Database:OpenConnection()
	assert(not self.connection, "(Database:OpenConnection) Connection already open")
	assert(self:CheckConnectionDetailsValidity(), "(Database:OpenConnection) Connection details missing")

	local hostString = self:GenerateHostString()
	local options = self:GenerateConnectionOptions()
	local conn = dbConnect("mysql", hostString, self.username, self.password, options)
	if conn then
		outputServerLog("Successfully connected to database")
		self.connection = conn
		self:GenerateTablesData()
		return true
	else
		outputDebugString( "Failed to open database connection due to error in dbConnect", 1 )
		return false
	end
end

function Database:CloseConnection()
	assert(isElement(self.connection), "(Database:CloseConnection) Connection not a valid object")

	destroyElement(self.connection)
	self.ClearTablesData()
	self.connection = nil
end

-- Generates information about tables in database, used mainly for AddRow
function Database:GenerateTablesData()
	assert(self.connection, "(Database:GenerateTablesData) No DB Connection")

	local fieldString = ("Tables_in_%s"):format(self.dbName)
	local tables = self:Query(true, "SHOW TABLES" )
	if tables and type(tables) == "table" then
		for _,tData in ipairs(tables) do
			-- Generate DatabaseTable class instance for that table
			local table = string.lower(tData[fieldString])
			local dbTable = DatabaseTable(table)
			-- Get columns data for table
			local tabData = self:Query(true, "DESCRIBE `??`", table)
			if tabData and type(tabData) == "table" then
				dbTable:ProcessColumnsData(tabData)
			end
			self.dbTablesData[table] = dbTable
		end
	else
		return false
	end
	return true
end

function Database:GetTableData(tab)
	return self.dbTablesData[string.lower(tab)]
end

-- Clears information about tables in database
function Database:ClearTablesData()
	self.dbTablesData = {}
end

-- Refresh informaion about tables in database
function Database:RefreshTablesData()
	self:ClearTablesData()
	self:GenerateTablesData()
end

function Database:Query(async, query, ...)
	assert(self.connection, "(Database:Query) No DB Connection")
	assert(type(async) == "boolean", "(Database:Query) Wrong async argument")
	assert(type(query) == "string", "(Database:Query) Wrong query")

	local isAsync = false
	if async then
		-- Check if we are running in coroutine, if not set mode to not async
		local curCoroutine = coroutine.running()
		if curCoroutine and curCoroutine ~= "main" then
			isAsync = true
		end
	end

	local queryStr = dbPrepareString(self.connection, query, ...)
	-- If we are running in async mode, generate required data
	if isAsync then
		local queryInfo = {self.curAsyncQueryID}
		self.asyncQueryTable[self.curAsyncQueryID] = coroutine.running()
		self.curAsyncQueryID = self.curAsyncQueryID+1

		local han = dbQuery( bind(Database.AsyncQueryCallback, self), queryInfo, self.connection, query, ... )
		local ret,numAffected,lastID = coroutine.yield()
		return ret,numAffected,lastID
	else
		local han = dbQuery( self.connection, query, ... )
		local ret,numAffected,lastID = dbPoll(han, -1)
		if ret == false then
			error(("(Database:Query) Error while processing query: (%d)%s"):format(numAffected, lastID))
		end
		return ret,numAffected,lastID
	end
end

function Database:Exec(query, ...)
	assert(self.connection, "(Database:Exec) No DB Connection")
	assert(type(query) == "string", "(Database:Exec) Wrong query")

	-- outputServerLog(dbPrepareString(self.connection, query, ...))
	return dbExec(self.connection, query, ...)
end

-- Adds row from given hash table, eg. {name="newName",color="255;0;0"}
function Database:AddRow(retID, tab, row)
	assert(self.connection, "(Database:AddRow) No DB Connection")
	assert(type(retID) == "boolean", "(Database:AddRow) Wrong retID argument")
	assert(type(tab) == "string", "(Database:AddRow) Wrong tab name")
	assert(type(row) == "table", "(Database:AddRow) Wrong row")
	assert(self:GetTableData(tab), "(Database:AddRow) No table matching given table name")

	local dbTable = self:GetTableData(tab)
	local colsString = ""
	local valsString = ""
	local build = {}
	local vals = {}
	local i = 1
	for col,val in pairs(row) do
		assert(type(col) == "string", "(Database:AddRow) Non string col")
		assert(dbTable:ContainsColumn(col), "(Database:AddRow) Table `"..tab.."` doesn't containg column `"..tostring(col).."`")
		if i~=1 then
			colsString = colsString .. ","
			valsString = valsString .. ","
		end
		colsString = colsString .. "??"
		valsString = valsString .. "?"
		table.insert(build, col)
		table.insert(vals, val)
		i = i+1
	end

	for _,val in ipairs(vals) do
		table.insert(build, val)
	end

	local queryStr = dbPrepareString(self.connection, "INSERT INTO `??` ("..colsString..") VALUES ("..valsString..")", tab, unpack(build))

	if retID then
		local _,_,id = self:Query(false, queryStr)
		return id
	else
		return self:Exec(queryStr)
	end
end

function Database:GetLastInsertID(tab, colOverride)
	assert(type(tab) == "string", "(Database:GetLastInsertID) Wrong tab name")
	assert(self:GetTableData(tab), "(Database:GetLastInsertID) No table matching given table name")

	local dbTable = self:GetTableData(tab)
	local fieldName = colOverride
	if not colOverride then
		fieldName = dbTable:GetAutoincrementedColumn()
	end
	assert(fieldName, "(Database:GetLastInsertID) No fieldName")

	local ret = self:Query(false, "SELECT MAX(??) as maxID FROM ??", fieldName, tab)
	assert(type(ret) == "table", "(Database:GetLastInsertID) No return from DB query")

	if #ret == 0 then
		return 1
	else
		if ret[1] and ret[1].maxID then
			return ret[1].maxID
		else
			return 1
		end
	end
end

function Database:AsyncQueryCallback(handle, queryID)
	local ret,numAffected,lastID = dbPoll(handle, 0)
	if ret == false then
		error(("(Database:AsyncQueryCallback) Error while processing query: (%d)%s"):format(numAffected, lastID))
	end

	local corout = self.asyncQueryTable[queryID]
	self.asyncQueryTable[queryID] = nil

	coroutine.resume( corout, ret, numAffected, lastID )
end