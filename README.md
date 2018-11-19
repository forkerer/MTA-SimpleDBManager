# MTA-SimpleDBManager
This resource is a simple database manager that can be used in MTA SA, it wasn't ever used in production and I'm sharing it because it probably wont have a chance to be used. It gives ability to query database asynchronously in coroutines.
&nbsp;
# File structure:
 - The resource is made of 2 classes:
   - Database class, it's a singleton that's responsible for connecting to database and querying informations from it
   - DatabaseTable class, each instance of this class is a table in database, it's used to validate input in Database:AddRow function, and to keep basic informations about tables accessible from lua.
 - This resource doesn't export any functions because custom classes can't be exported properly along with their metatables easily.

# Operating on Database
Example code showing usage of this resource
```lua
    -- This will set connection details for database
    Database():SetConnectionDetails("databaseName", 127.0.0.1, 1800, "someUsername", "superSecretPassword")
    
    -- This will open connection to database
    Database():OpenConnection()
    
    -- And this is example function that will be ran in coroutine
    function exampleFunc()
        local queryRes = Database():Query(true, "SELECT * FROM ?", "someTable")
        if queryRes then
            iprint(queryRes)
        end
        return true
    end
    
    -- This will run this function in coroutine, so it can use async database queries
    coroutine.resume(coroutine.create(exampleFunc))
    
    -- Close connection after everything was done.
    Database():CloseConnection()
```   


# All functions availible for Databases:
```lua
    Database:OpenConnection() --Opens connection with database
    Database:CloseConnection() --Closes connection with database
    Database:SetConnectionDetails(dbName, host, port, username, password) -- Sets base connection details, function argumest are self explanatory
    Database:SetDBName(name) -- Sets database name
    Database:SetHost(host) -- Sets host
    Database:SetPort(port) -- Sets port
    Database:SetUsername(username) -- Sets username
    Database:SetPassword(pass) -- Sets password
    Database:SetCharset(charset) -- Sets charset
    Database:GetDBName()
    Database:GetHost()
    Database:GetPort()
    Database:GetUsername()
    Database:GetPassword()
    Database:GetCharset()
    
    Database:SetOption(option, value) -- Sets given option to given value, for list of allowed options check https://wiki.multitheftauto.com/wiki/DbConnect
    Database:GetOption(option) -- Gets value of given option
    Database:RefreshTablesData() -- Refreshses informations about tables in database, should be used if there were any changes to database structure while script is running
    
    Database:Query(async, query, ...) -- Runs query in database and returns the result, runs asynchronously if the function is called inside coroutine and async argument is specified as true, otherwise runs blocking version
    Database:Exec(query, ...) -- Exectures statement in database, returns boolean indicating if execution was successful
    Database:AddRow(returnID, tab, row) -- Adds given row to the given table, it checks if database contains that table, the row should be table where index is column, and value at that index is value to be added to table, eg. Database:AddRow("People", {["name"]="John", ["surname"] = "Doe"}) will add John Doe to People table. If returnID is set to true, will return id of last auto_incremented columns in affected table, so pretty much id of inserted data.
    Database:GetLastInsertID(table, colOverride) -- Returns biggest id in given table, colOverride argument is optional, as the function tries to find which column is auto_incremented by itself. If searched id isn't an auto_incremented column, you need to specify colOverride, which is name of column that is id.
```


License
----
> ----------------------------------------------------------------------------
> Kamil Marciniak <github.com/forkerer> wrote this code. As long as you retain this 
> notice, you can do whatever you want with this stuff. If we
> meet someday, and you think this stuff is worth it, you can
> buy me a beer in return.
 ----------------------------------------------------------------------------


