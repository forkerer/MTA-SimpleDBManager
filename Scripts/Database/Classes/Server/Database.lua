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
	-- Check if there isn't an already opened connection
	if self.connection then
		outputDebugString( "Tried to open database connection, but there is a connection already open", 1 )
		return false
	end
	-- Check if all details were given
	if not self:CheckConnectionDetailsValidity() then
		outputDebugString( "Tried to open database connection, but some connection details are missing", 1 )
		return false
	end

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
	if self.connection and isElement(self.connection) then
		destroyElement(self.connection)
		self.ClearTablesData()
		self.connection = nil
	end
end

-- Generates information about tables in database, used mainly for AddRow
function Database:GenerateTablesData()
	if not self.connection then
		outputDebugString( "Tried to generate tables data in db, but no connection is open", 1 )
		return false
	end

	local tables = self:Query( "SHOW TABLES" )
	if tables and type(tables) == "table" then
		for _,table in ipairs(tables) do
			-- Generate DatabaseTable class instance for that table
			table = string.lower(table)
			local dbTable = DatabaseTable(table)
			-- Get columns data for table
			local tabData = self:Query("DESCRIBE `"..table.."`")
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

-- Clears information about tables in database
function Database:ClearTablesData()
	self.dbTablesData = {}
end

-- Refresh informaion about tables in database
function Database:RefreshTablesData()
	self:ClearTablesData()
	self:GenerateTablesData()
end

function Database:Query(query, ...)
	-- Check if connection is even open
	if not self.connection then
		outputDebugString( "Tried to query data from Database, but no connection is open", 1 )
		return false
	end
	-- Check if query was even given
	if type(query) ~= "string" then
		outputDebugString( "Tried to query data from Database, but no query was given", 1 )
		return false
	end

	local isAsync = true
	-- Check if we are running in coroutine, if not set mode to not async
	local curCoroutine = coroutine.running()
	if (not curCoroutine) or (curCoroutine == "main") then
		isAsync = false
	end

	-- If we are running in async mode, generate required data
	if isAsync then
		local queryInfo = {self.curAsyncQueryID}
		self.asyncQueryTable[self.curAsyncQueryID] = curCoroutine
		self.curAsyncQueryID = self.curAsyncQueryID+1

		local han = dbQuery( bind(Database.AsyncQueryCallback, self), queryInfo, self.connection, query, ... )
		local ret = coroutine.yield()
		return ret
	else
		local han = dbQuery( self.connection, query, ... )
		return dbPoll(han, -1)
	end
end

function Database:Exec(query, ...)
	-- Check if connection is even open
	if not self.connection then
		outputDebugString( "Tried to exec Database query, but no connection is open", 1 )
		return false
	end
	-- Check if query was even given
	if type(query) ~= "string" then
		outputDebugString( "Tried to query data from Database, but no query was given", 1 )
		return false
	end

	return dbExec(self.connection, query, ...)
end

-- Adds row from given hash table, eg. {name="newName",color="255;0;0"}
function Database:AddRow(tab, row)
	-- Check if connection is even open
	if not self.connection then
		outputDebugString( "Tried to add row to Database, but no connection is open", 1 )
		return false
	end
	if not (tab and type(tab)=="string") then
		outputDebugString( "Tried to add row to table in Database, but no table was given" )
		return false
	end
	if not (row and type(row)=="table") then
		outputDebugString( "Tried to add row to table in Database, but no row data were given" )
		return false
	end
	if not self.dbTablesData[tab] then
		outputDebugString( "Tried to add row to table in Database, but DB doesn't contain such table: "..tostring(tab) )
		return false
	end

	local dbTable = self.dbTablesData[tab]

	local colsString = ""
	local valsString = ""
	local columns = {}
	local vals = {}
	local i = 1
	for col,val in pairs(row) do
		if dbTable:ContainsColumn(col) then
			if i~=1 then
				colsString = colsString .. ","
				valsString = valsString .. ","
			end
			colsString = colsString .. col
			valsString = valsString .. "?"
			table.insert(vals, val)
			i = i+1
		else
			outputDebugString( "Tried inserting row to table: "..tostring(tab)..", but table doesn't contain given column: "..tostring(col), 1 )
			return false
		end
	end

	return self:Exec("INSERT INTO `"..tab.."` ("..colsString..") VALUES ("..valsString..")", unpack(vals) )
end

function Database:AsyncQueryCallback(handle, queryID)
	local ret = dbPoll(handle, 0)
	local corout = self.asyncQueryTable[queryID]
	self.asyncQueryTable[queryID] = nil

	coroutine.resume( corout, ret )
end