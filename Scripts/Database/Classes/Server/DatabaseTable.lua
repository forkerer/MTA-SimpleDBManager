-- ----------------------------------------------------------------------------
-- Kamil Marciniak <github.com/forkerer> wrote this code. As long as you retain this 
-- notice, you can do whatever you want with this stuff. If we
-- meet someday, and you think this stuff is worth it, you can
-- buy me a beer in return.
-- ----------------------------------------------------------------------------

DatabaseTable = {}
DatabaseTable.metatable = {
    __index = DatabaseTable,
}
setmetatable( DatabaseTable, { __call = function(self,...) return self:New(...) end } )

function DatabaseTable:New(name)
	local instance = setmetatable( {}, DatabaseTable.metatable )

	instance.name = string.lower(name)
	instance.columns = {}

	return instance
end

function DatabaseTable:ProcessColumnsData(cols)
	for ind,col in pairs(cols) do
		self:AddColumn(col)
	end
end

function DatabaseTable:AddColumn(col)
	self.columns[string.lower(col.Field)] = col
end

function DatabaseTable:ContainsColumn(col)
	if self.columns[string.lower(col)] then
		return true
	end
	return false
end

function DatabaseTable:GetColumn(col)
	return self.columns[string.lower(col)]
end

function DatabaseTable:IsColumnRequired(col)
	local tab = self.columns[string.lower(col)]
	if tab then
		return (tab.Null == "NO") and (tab.Default == "" or (not tab.Default)) -- If column is not nullable, and it doesn't have default vaule, then it is required
	end
	return false
end