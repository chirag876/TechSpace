/*
-----------------------------------------------------------------------------------
 Script: Export Stored Procedures to .sql Files
 Technology: PowerShell + SMO (SQL Server Management Objects)

 Purpose:
   - Connects to a given SQL Server and database.
   - Scripts all user-defined stored procedures (ignores system objects).
   - Saves each stored procedure as an individual .sql file.

 Features:
   - Creates an output folder (subfolder named after Server + Database).
   - Script includes schema, headers, and database context ("USE [DatabaseName]").
   - Outputs one .sql file per stored procedure.
   - Encodes files in UTF-8.

 Parameters to Configure:
   - $serverName     -> SQL Server instance name.
   - $databaseName   -> Target database name.
   - $rootOutputFolder -> Root folder where scripts will be saved.

 Output:
   - Files named as: [SchemaName]_[StoredProcedureName].sql
   - Location: $rootOutputFolder\$serverName\$databaseName\

 Use Cases:
   - Backup stored procedure definitions.
   - Version control of database objects.
   - Migration between environments (Dev → Test → Prod).
   - Documentation of existing stored procedures.
   
How to Run:
   1. Save this script with a `.ps1` extension, e.g., `ExportSPs.ps1`.
   2. Open Windows PowerShell (Run as Administrator).
   3. Navigate to the folder where the script is saved.
      Example: `cd F:\SQLScripts`
   4. Run the script:
         `.\ExportSPs.ps1`
   5. If execution policy blocks it, run:
         `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
         (then re-run the script).
   6. After execution, check the output folder for generated .sql files.
-----------------------------------------------------------------------------------
*/



# Load SMO Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

# Define SQL Server connection details
$serverName = ""          # Replace with your SQL Server name
$databaseName = ""      # Replace with your database name
$rootOutputFolder = "F:SQLScripts"  #Replace with your desired output folder
$outputFolder =  "$rootOutputFolder$serverName$databaseName"      #Creating Subfolder with Database Name

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

try {
    # Connect to the SQL Server
    Write-Host "Connecting to SQL Server..." -ForegroundColor Cyan
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    $database = $server.Databases[$databaseName]

    # Check if the database exists
    if ($null -eq $database) {
        Write-Error "Database '$databaseName' not found on server '$serverName'."
        exit
    }

    # Scripter object and options
    $scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter $server
    $scripter.Options.ScriptSchema = $true                   # Script schema only
    $scripter.Options.ScriptData = $false                    # No data scripting
    $scripter.Options.ToFileOnly = $true                     # Output to file
    $scripter.Options.IncludeHeaders = $true                 # Include headers
    $scripter.Options.AppendToFile = $false                  # Overwrite file
    $scripter.Options.Encoding = [System.Text.Encoding]::UTF8
    $scripter.Options.ScriptDrops = $false                   # Don't script DROP statements
    $scripter.Options.IncludeDatabaseContext = $true         # Include "USE [DatabaseName]"

    # Iterate through all stored procedures
    Write-Host "Scripting out stored procedures..." -ForegroundColor Green
    foreach ($storedProcedure in $database.StoredProcedures) {
        if ($storedProcedure.IsSystemObject -eq $false) {
            $scriptName = "$($storedProcedure.Schema)_$($storedProcedure.Name).sql"
            $scriptPath = Join-Path -Path $outputFolder -ChildPath $scriptName

            # Configure output file
            $scripter.Options.FileName = $scriptPath

            # Generate the script
            $scripter.Script($storedProcedure)

            Write-Host "Scripted: $scriptName" -ForegroundColor Yellow
        }
    }

    Write-Host "All stored procedures have been scripted to: $outputFolder" -ForegroundColor Green
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}