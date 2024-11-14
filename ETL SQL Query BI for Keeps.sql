USE [C23156919J]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


Create procedure [stage].[usp_Upsert] 

(
@tableName as varchar(100) 
)
as 

BEGIN
	
    SET NOCOUNT ON;


DECLARE @dst NVARCHAR(1000) 
SET @dst = '[C23156919J].[stage].' + @tablename ;
--print @dst
DECLARE @src NVARCHAR(1000) 
SET @src = '[C23156919J].[extract].'+ @tablename ;
DECLARE @eqPK NVARCHAR(1000) 
DECLARE @neColumns NVARCHAR(max)
DECLARE @updColumns NVARCHAR(max)
DECLARE @updColumnsIsNull NVARCHAR(max) -- this string does a compare by checking ISNULL(SRC.Columnname,'') <> ISNULL(DST.Columnname,'') as update failing if column is null
DECLARE @insColumn NVARCHAR(max) 
DECLARE @srcColumns NVARCHAR(max)
DECLARE @dstPrimaryKeys TABLE ([name] sysname) 

INSERT INTO @dstPrimaryKeys SELECT c.name FROM sys.indexes i 
INNER JOIN sys.index_columns ic on ic.object_id = i.object_id AND ic.index_id = i.index_id
INNER JOIN sys.columns c on c.object_id = i.object_id and c.column_id = ic.column_id
WHERE i.is_primary_key = 1 and 
i.object_id = object_id(@dst)  
--select * from @dstPrimaryKeys

SELECT @eqPK = COALESCE(@eqPK + ' AND ', '') + 't.' + name + '=' + 's.' + name FROM @dstPrimaryKeys
--print @eqPK

SELECT @updColumns = COALESCE(@updColumns + ',', '') + 't.' + name + '=' + 's.' + name
FROM sys.columns WHERE object_id = object_id(@dst) AND name NOT IN (SELECT name FROM @dstPrimaryKeys)
--print @updColumns

SET @neColumns = Replace(Replace(@updColumns, ',', ' OR '), '=', '<>')
--print @neColumns


SET @updColumnsIsNull = REPLACE ( REPLACE(Replace(@updColumns, ',', ','''') OR ') , 't.','ISNULL(t.') , '='  , ', '''') <> ISNULL(' )
						
							+ ', '''')'
--print @updColumnsIsNull

SELECT @insColumn = COALESCE(@insColumn + ',', '') + name
FROM sys.columns WHERE object_id = object_id(@dst)
--print @insColumn

SELECT @srcColumns = COALESCE(@srcColumns + ',', '') + 's.' + name
FROM sys.columns WHERE object_id = object_id(@dst)
--print @srcColumns


DECLARE @tsql nvarchar(max) = 
--'SET IDENTITY_INSERT ' + @dst + ' ON;' +
'MERGE ' + @dst + ' AS t ' +
'USING ' + @src + ' AS s ' +
'ON (' + @eqPK + ') ' +
--'WHEN MATCHED AND ' + @neColumns + ' THEN ' +
'WHEN MATCHED AND ' + @updColumnsIsNull + ' THEN ' +
'UPDATE SET ' + @updColumns + 
' WHEN NOT MATCHED BY TARGET THEN INSERT (' + @insColumn + ') ' +
'VALUES (' + @srcColumns + ') ;' 



--PRINT @tsql

EXEC sp_executesql @tsql

END