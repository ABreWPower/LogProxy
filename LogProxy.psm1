<#
.SYNOPSIS
Creates a Proxy function for Write-Error, Write-Warning, Write-Host, Write-Debug, and Write-Verbose to also log to file
	
.DESCRIPTION
The main goal of this logger is that it can placed in an already existing script that uses write- commands without having to 
change features by creating Proxy functions for Write-Error, Warning, Host, Debug, and Verbose.  These proxy functions allow 
the script to log to a file as well as the screen output.  When logging to the script it will reformat the string to add 
extra useful information. In order to log to file you must create the log file then call the initialization function to setup 
the log file.  The module has the ablity to set different log levels (ERROR, WARNING, INFO, DEBUG, VERBOSE), which can be 
used to controll what information is written to the log file.  

Log Level in more details: Log levels determine which Write- commands get added to the log file and are addative in the folling 
order ERROR, WARNING, INFO, DEBUG, VERBOSE.  This means that if you select ERROR only ERRORs will show.  If you select INFO, 
ERRORs, WARNINGs, and INFOs will show.  If you select VERBOSE all files will be writen the log file.

The setup functions will "throw" errors if problems are encountered therefore it should be place in a try block. For Write-Error 
a stack trace (Get-PSCallStack) will proceed the message that was passed in.

The log will be formatted like:
    [2017-04-23T16:02:43][ ][VERBOSE][C:\Dev\GitHubProjects\LogProxy\Tests\LogProxy.Tests.ps1:Not In a Function:410][Check Name Length][Owner]
    or [2017-04-23T16:02:43][ ][VERBOSE][LogProxy.Tests.ps1:Not In a Function:410][Check Name Length][Owner]
by default, to change the format change the code in the Write-ToOutput function.


.NOTES
NAME:     LogProxy
AUTHOR:   Adam Wickersham
VERSION:  1.0
LASTEDIT: 23APR2017
#>

Add-Type 'public enum LogLevel {ERROR, WARNING, INFO, DEBUG, VERBOSE}'

# Set module defaults so functions don't have to be called from importing script
[String]$Script:LogPath = ""
$Script:LogLevel = "INFO"
$Script:ScriptNameLength = "Long" # This variable should be either long or short and controlls if the full path is writen to log or just the filename


Function Set-LogFile() {
    <#
	.SYNOPSIS
	Sets the Log file location.
	
	.DESCRIPTION
	Sets the script Log file location for the other functions to use.
    
	.PARAMETER LogPath
	Specifies the path of the log file.  This folder structure will not automatically get generated and must be created manually.
    
	.EXAMPLE
	Set-LogFile -LogPath "C:\Admin\Logs\TestModule\Log.Log"; Note: "C:\Admin\Logs\TestModule" must already exist on the computer for the module to create the log file
    
	.NOTES
    NAME:     Set-LogFile
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 23APR2017
	#>

    Param(
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            # Get Parent Folder and check that it exists
            $LogFile = $_
            $LogDir = [System.IO.Path]::GetDirectoryName($LogFile)
            Test-Path $LogDir
        })] 
        [String]$LogPath
    )

    If ((Test-Path $LogPath) -eq $False) {
        New-Item $LogPath -ItemType File | Out-Null
    }

    If ((Test-IsWritable -Path $LogPath) -eq $False) {
            Throw "The Log file is unable to be writen to by the current user at this time."
    }

    $Script:LogPath = $LogPath
}

function Test-IsWritable(){
    <#
    .SYNOPSIS
        Command tests if a file is present and writable.
    
    .DESCRIPTION
        Command to test if a file is writeable.  This does not check permissions on directories and
        will just return false
    
    .PARAMETER Path
        Psobject containing the path or object of the file to test for write access.

    .OUTPUTS
        Returns true if file can be opened for write access, otherwise it returns false.

    .EXAMPLE
        Test-IsWritable -path $foo
        $bar | Test-IsWriteable
    
    .NOTES
    NAME:     Test-IsWritable
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 08JUL2015
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,
                   ValueFromPipeline=$True)]
        [psobject]$Path
    )

    process{
        # Test if file $Path is writeable
        If (Test-Path -Path $Path -PathType Leaf){
            # Check if file is readable
            $Target = Get-Item $Path -Force
            Try {
                            # Trying to openwrite
                            $Writestream = $Target.Openwrite()
                            $Writestream.Close() | Out-Null
                            Write-Output $True
            }
            Catch {
                            # Openwrite failed and file is not writable
                            Write-Output $False
            }
        }
        else {
            # File Path does not exist or is a directory
            Write-Output $False
        }
    }
}

Function Get-LogFile() {
    <#
	.SYNOPSIS
	Gets the Log file location.
	
	.DESCRIPTION
	Gets the Log file location set by the Set-LogFile function.

    .OUTPUTS
    String

	.EXAMPLE
	Get-LogFile
    
	.NOTES
    NAME:     Get-LogFile
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    Return $Script:LogPath
}

Function Stop-LogFile() {
    <#
	.SYNOPSIS
	Clears the Log file location.
	
	.DESCRIPTION
	Sets the Log file location to a blank string to clear it. This will cause the code to stop logging to file, but will still write to screen
    
	.EXAMPLE
	Clear-LogFile
    
	.NOTES
    NAME:     Stop-LogFile
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    $Script:LogPath = ""
}

Function Clear-LogFile() {
    <#
	.SYNOPSIS
	Removes the Log file.
	
	.DESCRIPTION
	Removes the Log file set by Set-LogFile.  This can be used if you want to start a clean log file.
    
	.EXAMPLE
	Clear-Log
    
	.NOTES
    NAME:     Clear-Log
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>
    
    If ($Script:LogPath.Length -ne 0) {
        If ((Test-Path $Script:LogPath) -eq $true){ 
            Remove-Item $Script:LogPath
        }
    }
}

Function Set-ScriptNameLength() {
    <#
	.SYNOPSIS
	Set the length of the script name.
	
	.DESCRIPTION
	Sets the length of the script name to either long or short and controlls if the full path is writen to log or just the filename of log messages.
    
    .PARAMETER ScriptNameLength
	Specifies the length of the script name.  Either Long, or Short.
    
	.EXAMPLE
	Set-ScriptNameLength -ScriptNameLength Long
    Set-ScriptNameLength -ScriptNameLength Short
    
	.NOTES
    NAME:     Set-LogLevel
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 12JUl2015
	#>

    Param(
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Long", "Short")]
        [String]$ScriptNameLength
    )

    $Script:ScriptNameLength = $ScriptNameLength

}

Function Set-LogLevel() {
    <#
	.SYNOPSIS
	Sets the level of log messages.
	
	.DESCRIPTION
	Sets the level of log messages. to write to the Log file.
    
    .PARAMETER LogLevel
	Specifies the log level to write to a log file.  Either ERROR, WARNING, INFO, DEBUG, or VERBOSE

    Log Level in more details: Log levels determine which Write- commands get added to the log file and are addative in the folling 
    order ERROR, WARNING, INFO, DEBUG, VERBOSE.  This means that if you select ERROR only ERRORs will show.  If you select INFO, 
    ERRORs, WARNINGs, and INFOs will show.  If you select VERBOSE all files will be writen the log file.
    
	.EXAMPLE
	Set-LogLevel -LogLevel ERROR
    Set-LogLevel -Loglevel DEBUG
    
	.NOTES
    NAME:     Set-LogLevel
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    Param(
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE")]
        [LogLevel]$LogLevel
    )

    $Script:LogLevel = $LogLevel
}

Function Get-LogLevel() {
    <#
	.SYNOPSIS
	Gets the Log level.
	
	.DESCRIPTION
	Gets the Log level set by the Set-LogLevel function.

    .OUTPUTS
    LogLevel

	.EXAMPLE
	Get-LogLevel
    
	.NOTES
    NAME:     Get-LogLevel
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    Return $Script:LogLevel
}

Function Write-Error() {
    <#
	.SYNOPSIS
	A proxy function for Write-Error to allow it to also log to a file.
	
	.DESCRIPTION
	A proxy function for Write-Error to allow it to also log to a file and also write to STDOUT like normal.  The Log file location must be set with the Set-LogFile function.

    .OUTPUTS
    Entry in the Log File if applicable and STDOUT

	.EXAMPLE
    Write-Error <ErrorRecord> <ErrorId>
    Write-Error -ErrorRecord <ErrorRecord> -ErrorId <ErrorId>
    Write-Error <Exception> <Message> <ErrorId>
    Write-Error -Exception <Exception> -Message <Message> -ErrorId <ErrorId>
	Write-Error <Message>
    Write-Error -Message <Message>
    
	.NOTES
    NAME:    Write-Error
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    [CmdletBinding()]
    Param ( 
            [Parameter(ParameterSetName='WithException', 
                       Mandatory=$true)]
            [System.Exception]$Exception,

            [Parameter(ParameterSetName='WithException')]
            [Parameter(ParameterSetName='NoException', 
                       Mandatory=$true, 
                       Position=0, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromRemainingArguments=$true)]
            [Alias('Msg')]
            [AllowEmptyString()]
            [AllowNull()]
            $Message, # Don't declare type so that anything can be passed in then converted to a string

            [Parameter(ParameterSetName='ErrorRecord',
                       Mandatory=$true)]
            [System.Management.Automation.ErrorRecord]$ErrorRecord,

            [Parameter(ParameterSetName='NoException')]
            [Parameter(ParameterSetName='WithException')]
            [System.Management.Automation.ErrorCategory]$Category,

            [Parameter(ParameterSetName='WithException')]
            [Parameter(ParameterSetName='NoException')]
            [string]$ErrorId,

            [Parameter(ParameterSetName='NoException')]
            [Parameter(ParameterSetName='WithException')]
            [System.Object]$TargetObject,

            [string]$RecommendedAction,

            [Alias('Activity')]
            [string]$CategoryActivity,

            [Alias('Reason')]
            [string]$CategoryReason,

            [Alias('TargetName')]
            [string]$CategoryTargetName,

            [Alias('TargetType')]
            [string]$CategoryTargetType
        )

    Process {
        # Create a custom message depending on the parameter set used
        If ($ErrorRecord -ne $Null) { # Paramater Set ErrorRecord
            $ModMessage = "$($ErrorRecord.Exception) $($ErrorRecord.FullyQualifiedErrorId)"
        }
        ElseIf ($Exception -ne $Null) { # Paramater Set WithException
            If ($Message.Count -gt 1) {
                $Message = $Message -join '; '
            }
            
            $ModMessage = "$Exception $Message $ErrorId"
        }
        Else { # Parameter Set NoException
            If ($Message.Count -gt 1) {
                $Message = $Message -join '; '
            }

            $ModMessage = "$Message $ErrorId"
        }

        Write-ToOutput -Message $ModMessage -PlaceErrorChar $true -LogLevel "ERROR" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Error'

        # Write out the stack-trace to help the developers
        $StackTrace = (Get-PSCallStack) -join '; '
        Write-ToOutput -Message $StackTrace -PlaceErrorChar $true -LogLevel "ERROR" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Error'
    }
}

Function Write-Warning() {
    <#
	.SYNOPSIS
	A proxy function for Write-Warning to allow it to also log to a file.
	
	.DESCRIPTION
	A proxy function for Write-Warning to allow it to also log to a file and also write to STDOUT like normal.  The Log file location must be set with the Set-LogFile function.

    .OUTPUTS
    Entry in the Log File if applicable and STDOUT

	.EXAMPLE
	Write-Warning <Message>
    Write-Warning -Messsage <Message>
    
	.NOTES
    NAME:     Write-Warning
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    [CmdletBinding()]
    Param ( 
            [Parameter(Mandatory=$true, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromRemainingArguments=$true)]
            [Alias('Msg')]
            [AllowNull()]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            $Message # Don't declare type so that anything can be passed in then converted to a string
        )

    Process {
        If ($Message.Count -gt 1) {
            $Message = $Message -join '; '
        }

        Write-ToOutput -Message $Message -PlaceErrorChar $false -LogLevel "WARNING" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Warning'
    }
}

Function Write-Host() {
    <#
	.SYNOPSIS
	A proxy function for Write-Host to allow it to also log to a file.
	
	.DESCRIPTION
	A proxy function for Write-Host to allow it to also log to a file and also write to STDOUT like normal.  The Log file location must be set with the Set-LogFile function.

    .OUTPUTS
    Entry in the Log File if applicable and STDOUT

	.EXAMPLE
	Write-Host <Message>
    Write-Host -Object <Message>
    Write-Host -Object <Message>
    Write-Host -Object <Message> -NoNewLine; Only works for writing to screen
    Write-Host -Object <Message> -ForegroundColor <Color> -BackgroundColor <Color>
    
	.NOTES
    NAME:     Write-Host
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>
    
    [CmdletBinding()]
    Param ( 
            [Parameter(ParameterSetName='Object',
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromRemainingArguments=$true)]
            [AllowEmptyString()]
            $Object, # Don't declare type so that anything can be passed in then converted to a string

            [switch]$NoNewline,

            [System.Object]$Separator,

            [System.ConsoleColor]$ForegroundColor,

            [System.ConsoleColor]$BackgroundColor
        )

    Process {        
        ForEach ($Txt In $Object) {
            If ($Message.Length -eq 0 ) {
                $Message = "$Txt"
            }
            Else { 
                $Message = "$Message $Txt"
            }
        }
        
        Write-ToOutput -Message $Message -PlaceErrorChar $false -LogLevel "INFO" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Host'
    }
}

Function Write-Debug() {
    <#
	.SYNOPSIS
	A proxy function for Write-Debug to allow it to also log to a file.
	
	.DESCRIPTION
	A proxy function for Write-Debug to allow it to also log to a file and also write to STDOUT like normal.  The Log file location must be set with the Set-LogFile function.

    .OUTPUTS
    Entry in the Log File if applicable and STDOUT

	.EXAMPLE
	Write-Debug <Message>
    Write-Debug -Message <Message>
    
	.NOTES
    NAME:    Write-Debug
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    [CmdletBinding()]
    Param ( 
            [Parameter(Mandatory=$true, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromRemainingArguments=$true)]
            [Alias('Msg')]
            [AllowEmptyString()]
            $Message # Don't declare type so that anything can be passed in then converted to a string
        )

    Process {

        If ($Message.Count -gt 1) {
            $Message = $Message -join '; '
        }

        Write-ToOutput -Message $Message -PlaceErrorChar $false -LogLevel "DEBUG" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Debug'
    }
}

Function Write-Verbose() {
    <#
	.SYNOPSIS
	A proxy function for Write-Verbose to allow it to also log to a file.
	
	.DESCRIPTION
	A proxy function for Write-Verbose to allow it to also log to a file and also write to STDOUT like normal.  The Log file location must be set with the Set-LogFile function.

    .OUTPUTS
    Entry in the Log File if applicable and STDOUT

	.EXAMPLE
	Write-Verbose <Message>
    Write-Verbose -Message <Message>
    
	.NOTES
    NAME:    Write-Verbose
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 06JUN2015
	#>

    [CmdletBinding()]
    Param ( 
            [Parameter(Mandatory=$true, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromRemainingArguments=$true)]
            [Alias('Msg')]
            [AllowEmptyString()]
            $Message # Don't declare type so that anything can be passed in then converted to a string
        )

    Process {
        If ($Message.Count -gt 1) {
            $Message = $Message -join '; '
        }

        Write-ToOutput -Message $Message -PlaceErrorChar $false -LogLevel "VERBOSE" -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Verbose'
    }
}

Function Write-ToOutput() {
    <#
	.SYNOPSIS
	A generic proxy function for Write- commands.
	
	.DESCRIPTION
	A generic proxy function for Write- commands that allows the input to be piped out to a log file
    as well as the usual STDOUT message.  It only writes out to the log file if it has been set to a
    valid path.

    .OUTPUTS
    Writes to the log file if set and STDOUT

	.EXAMPLE
	Write-ToOutput -Message $Message -LogPath $(Get-LogFile) -LogLevel $([LogLevel]::DEBUG) -PlaceErrorChar $false -OriginalCMD 'Microsoft.PowerShell.Utility\Write-Debug'
    
	.NOTES
    NAME:     Write-ToOutput
	AUTHOR:   Adam Wickersham
    VERSION:  1.0
    LASTEDIT: 08JUL2015
	#>

    [CmdletBinding()]
    Param ( 
            [Parameter(Mandatory=$true, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true,
                       valueFromRemainingArguments=$true)]
            [AllowNull()]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            [String]$Message,

            [Parameter(Mandatory=$false, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true)]
            [AllowNull()]
            [System.Object]$LogPath = (Get-LogFile),

            [Parameter(Mandatory=$false, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [LogLevel]$LogLevel = (Get-LogLevel),

            [Parameter(Mandatory=$false, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true)]
            [Boolean]$PlaceErrorChar,

            [Parameter(Mandatory=$false, 
                       ValueFromPipeline=$true,
                       ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [System.Object]$OriginalCMD
        )
    
    # Creates the command to call the original cmdlet that comes with the system
    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand($OriginalCMD, [System.Management.Automation.CommandTypes]::Cmdlet)

    # If LogPath is set write out the message in our format
    If ($LogPath.Length -ne 0) {
        If ($PlaceErrorChar -eq $true) {
            $ErrorChar = "#"
        }
        Else {
            $ErrorChar = " "
        }
        
        # Gets the date and puts it in the ISO 8601 format without dashes or letters
        $DateTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

        # Calling script name and Function name are hard coded to get the 3 stack item, which will the be original calling function or script, the second 
        # is the Write- proxy function, and the first is the Write-ToOutput function itself
        $StackTrace = (Get-PSCallStack)[2]

        If ($Script:ScriptNameLength.Equals("Long")) {
            $CallingScriptName = $StackTrace.ScriptName
        }
        Else { # must equal Short
            $CallingScriptName = $StackTrace.Location.Split(":")[0]
        }

        $FunctionName = $StackTrace.FunctionName
        If ($FunctionName.Contains("<ScriptBlock>")) {
            $FunctionName = "Not In a Function"
        }

        $ScriptLineNumber = $StackTrace.ScriptLineNumber

        # Gets the Script Name, the calling Function Name, and the Line number in the calling script
        $LocationOfCall = "$($CallingScriptName):$($FunctionName):$($ScriptLineNumber)"

        $UserName = [Environment]::UserName

        $SingleLineMessage = $Message -replace "`n", "" -replace "`r", "; " # TODO This line breaks some of the messages: VERBOSE: This; is; a; test; Verbose; message

        # Create the combined message to write to the log
        $ModMessage = "[$DateTime][$ErrorChar][$LogLevel][$LocationOfCall][$SingleLineMessage][$UserName]"
    }
    
    # Determine if the user specified either a log location then write to a file and/or to the console
    If ($LogPath.Length -ne 0) { # Write to a log file
        # Write the reformated string to the log file
        $LogLevelPassedIn = $LogLevel.Value__
        $LogLevelSetForModule = $Script:LogLevel.Value__
        If ($LogLevelPassedIn -le $LogLevelSetForModule) {
            Out-File -FilePath $LogPath -InputObject $ModMessage -Append
        }
    }

    # Write the object to the console
    & $wrappedCmd $Message
}
