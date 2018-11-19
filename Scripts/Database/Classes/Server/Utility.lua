-- ----------------------------------------------------------------------------
-- Kamil Marciniak <github.com/forkerer> wrote this code. As long as you retain this 
-- notice, you can do whatever you want with this stuff. If we
-- meet someday, and you think this stuff is worth it, you can
-- buy me a beer in return.
-- ----------------------------------------------------------------------------

function bind(func, ...)
	assert(type(func) == "function", "First argument to bind has to be function")
	local args = {...}
	return function(...) 
		local retTable = {}
		for _,val in ipairs(args) do
			retTable[#retTable+1] = val
		end
		for _,val in ipairs({...}) do
			retTable[#retTable+1] = val
		end
		func(unpack(retTable))
	end
end

function string.find2( str, f )
	local l1 = str:len()
	local l2 = f:len()
	for i=1,l1-l2+1 do
		local s = str:sub(i,i+l2-1)
		if s==f then return i end
	end
	return false
end