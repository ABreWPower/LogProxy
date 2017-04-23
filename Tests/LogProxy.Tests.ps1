<# 
    By running this through pester it actually tests out all of the Write- commands very well
    Note: this may need to be run as an administrator depending on your UAC settings
    Note2: this can not be run in the ISE as transcripts do not work

    NAME:     LogProxy Pester Tests
    AUTHOR:   Adam Wickersham
    VERSION:  1.1
    LASTEDIT: 23APR2017
#>

$CurrentLocation = (Split-Path -Parent $MyInvocation.MyCommand.Path).TrimEnd('Tests')
$UnitTest = "LogProxy"
Import-Module "$CurrentLocation$UnitTest" -Force

$Script:LogFile = "C:\Temp\Test.txt"
$Script:TestLogForTranscript = "$Env:TEMP\Test.txt"

# Turn on all preferences so they write to STDOUT and they can be captured
$Global:VerbosePreference = 2
$Global:DebugPreference = 2
$Global:WarningPreference = 2

If ((Test-Path -Path "C:\Temp") -eq $False) {
    New-Item -Path "C:\Temp" -ItemType Directory
}


Describe "Set, Get, Clear, and Remove LogFile" {

    It "Sets and gets the Log File Location" {
        Set-LogFile -LogPath "C:\TestLogProxy.txt"
        Get-LogFile | Should Be "C:\TestLogProxy.txt"
    }

    It "Should Remove Log File" {
        Clear-LogFile
        Test-Path -Path (Get-LogFile) | Should Be $False
    }

    It "Should not fail if log has already been removed" {
        Clear-LogFile
        Test-Path -Path (Get-LogFile) | Should Be $False
    }

    It "Sets and gets the Log File Location to a new location" {
        Set-LogFile -LogPath "C:\LogProxyTest.txt"
        Get-LogFile | Should Be "C:\LogProxyTest.txt"
    }

    It "Should Remove Log File" {
        Clear-LogFile
        Test-Path -Path (Get-LogFile) | Should Be $False
    }

    It "Should clear the log file location" {
        Stop-LogFile
        Get-LogFile | Should Be ""
    }

    It "Should fail to set log location to empty" {
        $TestFailed = $False
        Try {
            $ErrorActionPreference ="Stop"
            Set-LogFile -LogPath ""
            $ErrorActionPreference ="Continue"
        }
        Catch {
            $TestFailed = $True
        }
        $TestFailed | Should Be $True
    }

    It "Should fail to set log location to null" {
        $TestFailed = $False
        Try {
            $ErrorActionPreference ="Stop"
            Set-LogFile -LogPath
            $ErrorActionPreference ="Continue"
        }
        Catch {
            $TestFailed = $True
        }
        $TestFailed | Should Be $True
    }
}

Describe "Test-IsWritable" {

    Setup -File "TestFile.txt" ""

    It "Tests that a file is writable" {
        Test-IsWritable "$TestDrive\TestFile.txt" | Should Be $True
    }

    It "Should fail if the file is not there" {
        Test-IsWritable "$TestDrive\TestFile2.txt" | Should Be $False
    }

    It "Should fail if it is a folder" {
        Test-IsWritable "$TestDrive\TestFolder" | Should Be $False
    }
}

Describe "Set, and Get LogLevel" {
    It "Sets and gets Log Level to VERBOSE" {
        Set-LogLevel -LogLevel VERBOSE
        Get-LogLevel | Should Be ([LogLevel]::VERBOSE)
    }

    It "Sets and gets Log Level to DEBUG" {
        Set-LogLevel -LogLevel DEBUG
        Get-LogLevel | Should Be DEBUG
    }

    It "Sets and gets Log Level to WARNING" {
        Set-LogLevel -LogLevel WARNING
        Get-LogLevel | Should Be "WARNING"
    }

    It "Sets and gets Log Level to INFO" {
        Set-LogLevel -LogLevel INFO
        Get-LogLevel | Should Be INFO
    }

    It "Sets and gets Log Level to ERROR" {
        Set-LogLevel -LogLevel ERROR
        Get-LogLevel | Should Be ERROR
    }

    It "Set Log Level to invalid type" {
        $TestFailed = $False
        Try {
            $ErrorActionPreference ="Stop"
            Set-LogLevel TEST
            $ErrorActionPreference ="Continue"
        }
        Catch {
            $TestFailed = $True
        }
        $TestFailed | Should Be $True
    }
}

# Setup 2 functions for the rest of the tests to use
Function Invoke-PreWrite() {
    Param (
        [LogLevel]$LogLev = [LogLevel]::VERBOSE,
        [Boolean]$CheckLogFile = $True,
        [Boolean]$RemoveLog = $True
    )

    # Setup for the test
    If ($CheckLogFile -eq $True) {
        Set-LogFile -LogPath $Script:LogFile
    }
    Set-LogLevel -LogLevel $LogLev
    
    # Make sure the log file is clean
    If ($RemoveLog -eq $True) {
        Clear-LogFile
    }
    
    # Start capturing transcript
    $ErrorActionPreference = "SilentlyContinue"
    Start-Transcript -Path $Script:TestLogForTranscript -Force | Out-Null
}

Function Invoke-PostWrite() {
    [OutputType([Boolean])]
    Param (
        [String]$MessageText,
        [Boolean]$CheckLogFile = $True
    )
    
    Stop-Transcript | Out-Null
    $ErrorActionPreference = "Default"

    If ($CheckLogFile -eq $True) {
        Stop-LogFile # Make sure none of the Pester logging get put in the log file
    }

    $TestFailed = $True

    $SingleLineMessage = $Message -replace "`n", "" -replace "`r", "; "

    ForEach ($Line In (Get-Content $Script:TestLogForTranscript)) { # Loop through the trace file to find the line we need  
        If ($Line.Contains("$SingleLineMessage")) { 
            If ($CheckLogFile -eq $False) {
                # Don't want to check log, we are successful
                $TestFailed = $False
            }
            Else {
                ForEach ($Line2 In (Get-Content $Script:LogFile)) {
                    # Message Text was found trace file, now check the logged output
                    If ($Line2.Contains("$SingleLineMessage")) {
                        $TestFailed = $False
                        Break
                    }
                }
            }
        }
    }
    
    Remove-Item -Path $Script:TestLogForTranscript | Out-Null
    Return $TestFailed
}

Describe "Write-Verbose to STDOUT and Log" {
    $MessageTxt = "This is a test Verbose message"  
     
    It "Writes a Verbose message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Verbose $MessageTxt 
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Verbose message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Verbose -Message $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Verbose message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Verbose This is a test Verbose message
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }
}

Describe "Write-Debug to STDOUT and Log" {
    $MessageTxt = "This is a test Debug message"  
     
    It "Writes a Debug message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Debug $MessageTxt 
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Debug message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Debug -Message $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Debug message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Debug This is a test Debug message
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }
}

Describe "Write-Warning to STDOUT and Log" {
    $MessageTxt = "This is a test Warning message"  
     
    It "Writes a Warning message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Warning $MessageTxt 
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Warning message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Warning -Message $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Warning message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Warning This is a test Warning message
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }
}

Describe "Write-Host to STDOUT and Log" {
    $MessageTxt = "This is a test Host message"  
     
    It "Writes a Host message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Host $MessageTxt 
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Host message with object parameter to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Host -Object $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Host message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Host This is a test Host message
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    # TODO put extra cases for extra parameter in for Write-Host
    It "Writes a Host message with additional parameters to the STDOUT and Log" {
        Invoke-PreWrite  
        Write-Host -Message $MessageTxt -NoNewline $true -ForegroundColor Red -BackgroundColor Yellow
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    # Special test for Host since it excepts objects in
    $MessageTxt = "2 4 6 8 10"

    It "Writes a Host message with separtor with object passed in to the STDOUT and Log" {
        Invoke-PreWrite  
        Write-Host (2, 4, 6, 8, 10) -Separator "-----"
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }
}

Describe "Write-Error to STDOUT and Log" {
    $MessageTxt = "This is a test Error message"  
     
    It "Writes a Error message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Error $MessageTxt 
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Error message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Error -Message $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Error message to STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Error This is a test Error message
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Error WithException message STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Error -Exception [System.Exception] -Message $MessageTxt -ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Error ErrorRecord message STDOUT and the Log" {
        Invoke-PreWrite  
        
        $Exception = New-Object InvalidOperationException $MessageTxt
        $ErrorID = 'FileIsEmpty'
        $ErrorCategory = [Management.Automation.ErrorCategory]::InvalidOperation
        $Target = "Here"
        $ErrorRecord = New-Object Management.Automation.ErrorRecord $Exception, $ErrorID, $ErrorCategory, $Target

        Write-Error -ErrorRecord $errorRecord -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"

        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }

    It "Writes a Error NoException message STDOUT and the Log" {
        Invoke-PreWrite  
        Write-Error -Message $MessageTxt -ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Invoke-PostWrite -MessageText $MessageTxt | Should Be $False 
    }


    # TODO check that error writes out a stack trace somehow
}

Describe "Write to just STDOUT" {
    $MessageTxt = "Write Just to STDOUT"
    
    It "Writes a Verbose message to STDOUT and the Log" {
        Invoke-PreWrite -CheckLogFile $False
        Write-Verbose $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt -CheckLogFile $False | Should Be $False 
    }

    It "Writes a Debug message to STDOUT and the Log" {
        Invoke-PreWrite -CheckLogFile $False  
        Write-Debug -Message $MessageTxt
        Invoke-PostWrite -MessageText $MessageTxt -CheckLogFile $False | Should Be $False 
    }

    It "Writes a Warning message to STDOUT and the Log" {
        Invoke-PreWrite -CheckLogFile $False  
        Write-Warning Write Just to STDOUT
        Invoke-PostWrite -MessageText $MessageTxt -CheckLogFile $False | Should Be $False 
    }

    It "Writes a Error WithException message STDOUT and the Log" {
        Invoke-PreWrite -CheckLogFile $False  
        Write-Error -Exception [System.Exception] -Message $MessageTxt -ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Invoke-PostWrite -MessageText $MessageTxt -CheckLogFile $False | Should Be $False 
    }

    # Special test for Host since it excepts objects in
    $MessageTxt = "2 4 6 8 10 12"

    It "Writes a Host message with separtor with object passed in to the STDOUT and Log" {
        Invoke-PreWrite -CheckLogFile $False  
        Write-Host (2, 4, 6, 8, 10, 12) -Separator "-->"
        Invoke-PostWrite -MessageText $MessageTxt -CheckLogFile $False | Should Be $False 
    }
}

Describe "Set-ScriptNameLength" {
    $MessageTxt = "Check Name Length" 
    
    $TestFailed = $True

    It "Set-ScriptNameLength to Long" {
        Invoke-PreWrite

        Set-ScriptNameLength -ScriptNameLength Long
        Write-Verbose $MessageTxt

        If ((Invoke-PostWrite -MessageText $MessageTxt) -eq $False) { # Make sure normal 
            If ((Get-Content $Script:LogFile).Contains("Tests\LogProxy.Tests.ps1")) {
                $TestFailed = $False
            }
        }
        
        $TestFailed | Should Be $False 
    }

    It "Set-ScriptNameLength to Short" {
        Invoke-PreWrite

        Set-ScriptNameLength -ScriptNameLength Short
        Write-Verbose $MessageTxt

        If ((Invoke-PostWrite -MessageText $MessageTxt) -eq $False) { # Make sure normal 
            If ((Get-Content $Script:LogFile).Contains("[LogProxy.Tests.ps1")) {
                $TestFailed = $False
            }
        }
        
        $TestFailed | Should Be $False 
    }

    It "Set ScriptNameLenth to Invalid Type" {
        $TestFailed = $False
        Try {
            $ErrorActionPreference ="Stop"
            Set-ScriptNameLength -ScriptNameLength Test
            $ErrorActionPreference ="Continue"
        }
        Catch {
            $TestFailed = $True
        }
        $TestFailed | Should Be $True
    }
}

Describe "Check that it appends to the log file by default" {
    $MessageTxt1 = "Testing Log Appending 1"
    $MessageTxt2 = "Testing Log Appending 2"
    $MessageTxt3 = "Testing Log Appending 3"
    $MessageTxt4 = "Testing Log Appending 4"
    $MessageTxt5 = "Testing Log Appending 5"
    
    It "Writes message 1 in the log" {
        Invoke-PreWrite -RemoveLog $False
        Write-Verbose $MessageTxt1 
        Invoke-PostWrite -MessageText $MessageTxt1 -ClearLogFile $False | Should Be $False 
    }

    $TestFailed = $True  # Reset value inbetween steps

    It "Writes message 2 in the log" {
        Invoke-PreWrite -RemoveLog $False
        Write-Debug $MessageTxt2 

        If ((Invoke-PostWrite -MessageText $MessageTxt2 -ClearLogFile $False) -eq $False) { # This only check the message we just added
            ForEach ($Line In (Get-Content $Script:LogFile)) { # Loop through the trace file to find the line we need  
                If ($Line.Contains("$MessageText1")) { # Check for Message 1
                    $TestFailed = $False
                }
            }
        }

        $TestFailed | Should Be $False
    }

    $TestFailed = $True  # Reset value inbetween steps

    It "Writes message 3 in the log" {
        Invoke-PreWrite -RemoveLog $False  
        Write-Warning $MessageTxt3 

        If ((Invoke-PostWrite -MessageText $MessageTxt3 -ClearLogFile $False) -eq $False) { # This only check the message we just added
            ForEach ($Line In (Get-Content $Script:LogFile)) { # Loop through the trace file to find the line we need  
                If ($Line.Contains("$MessageText1")) { # Check for Message 1
                    If ($Line.Contains("$MessageText2")) { # Check for Message 2
                        $TestFailed = $False
                    }
                }
            }
        }

        $TestFailed | Should Be $False
    }

    $TestFailed = $True # Reset value inbetween steps

    It "Writes message 4 in the log" {
        Invoke-PreWrite -RemoveLog $False  
        Write-Host $MessageTxt4 
        
        If ((Invoke-PostWrite -MessageText $MessageTxt4 -ClearLogFile $False) -eq $False) { # This only check the message we just added
            ForEach ($Line In (Get-Content $Script:LogFile)) { # Loop through the trace file to find the line we need  
                If ($Line.Contains("$MessageText1")) { # Check for Message 1
                    If ($Line.Contains("$MessageText2")) { # Check for Message 2
                        If ($Line.Contains("$MessageText3")) { # Check for Message 3
                            $TestFailed = $False
                        }
                    }
                }
            }
        }

        $TestFailed | Should Be $False
    }

    $TestFailed = $True # Reset value inbetween steps

    It "Writes message 5 in the log" {
        Invoke-PreWrite -RemoveLog $False  
        Write-Error $MessageTxt5 

        If ((Invoke-PostWrite -MessageText $MessageTxt5 -ClearLogFile $False) -eq $False) { # This only check the message we just added
            ForEach ($Line In (Get-Content $Script:LogFile)) { # Loop through the trace file to find the line we need  
                If ($Line.Contains("$MessageText1")) { # Check for Message 1
                    If ($Line.Contains("$MessageText2")) { # Check for Message 2
                        If ($Line.Contains("$MessageText3")) { # Check for Message 3
                            If ($Line.Contains("$MessageText4")) { # Check for Message 4
                                $TestFailed = $False
                            }
                        }
                    }
                }
            }
        }

        $TestFailed | Should Be $False
    }
}

Function Invoke-LogLevelResults() {
    [OutputType([Int])]
    Param (
        [String]$LogMessage
    )

    $FoundNum = 0

    ForEach ($Line In (Get-Content $Script:LogFile)) { # Loop through the trace file to find the line we need
        If ($Line.Contains("$LogMessage 1")) { # Check for Message 1
            $FoundNum++
        }
        If ($Line.Contains("$LogMessage 2")) { # Check for Message 2
            $FoundNum++
        }
        If ($Line.Contains("$LogMessage 3")) { # Check for Message 3
            $FoundNum++
        }
        If ($Line.Contains("$LogMessage 4")) { # Check for Message 4
            $FoundNum++
        }
        If ($Line.Contains("$LogMessage 5")) { # Check for Message 5
            $FoundNum++
        }
    }

    Return $FoundNum
}

Describe "Test to make sure log levels filter properly" {
    # Verbose has already been tested extensively above
    
    $MessageTxt = "Test Debug Log Level"
    
    It "Test Debug Log Level" {
        Invoke-PreWrite -LogLev DEBUG

        Write-Error -Exception [System.Exception] -Message "$MessageTxt 1"-ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Write-Warning "$MessageTxt 2"
        Write-Host "$MessageTxt 3"
        Write-Debug "$MessageTxt 4" 
        Write-Verbose "$MessageTxt 5"       

        Invoke-PostWrite -MessageText "$MessageTxt 5" -ClearLogFile $False -CheckLogFile $False | Out-Null

        $FoundNum = Invoke-LogLevelResults -LogMessage $MessageTxt
        
        If ($FoundNum -eq 4) {
            $TestFailed = $False
        }
        
        $TestFailed | Should Be $False
    }

    $MessageTxt = "Test Info Log Level"

    It "Test Info Log Level" {
        Invoke-PreWrite -LogLev INFO

        Write-Error -Exception [System.Exception] -Message "$MessageTxt 1"-ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Write-Warning "$MessageTxt 2"
        Write-Host "$MessageTxt 3"
        Write-Debug "$MessageTxt 4" 
        Write-Verbose "$MessageTxt 5"         

        Invoke-PostWrite -MessageText "$MessageTxt 5" -ClearLogFile $False -CheckLogFile $False | Out-Null

        $FoundNum = Invoke-LogLevelResults -LogMessage $MessageTxt

        If ($FoundNum -eq 3) {
            $TestFailed = $False
        }
        
        $TestFailed | Should Be $False
    }

    $MessageTxt = "Test Warning Log Level"

    It "Test Warning Log Level" {
        Invoke-PreWrite -LogLev WARNING

        Write-Error -Exception [System.Exception] -Message "$MessageTxt 1"-ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Write-Warning "$MessageTxt 2"
        Write-Host "$MessageTxt 3"
        Write-Debug "$MessageTxt 4" 
        Write-Verbose "$MessageTxt 5"       

        Invoke-PostWrite -MessageText "$MessageTxt 5" -ClearLogFile $False -CheckLogFile $False | Out-Null

        $FoundNum = Invoke-LogLevelResults -LogMessage $MessageTxt

        If ($FoundNum -eq 2) {
            $TestFailed = $False
        }
        
        $TestFailed | Should Be $False
    }

    $MessageTxt = "Test Error Log Level"

    It "Test Error Log Level" {
        Invoke-PreWrite -LogLev ERROR

        Write-Error -Exception [System.Exception] -Message "$MessageTxt 1"-ErrorId 100 -Category AuthenticationError -TargetObject "test" -RecommendedAction "fix this problem" -CategoryActivity "Error" -CategoryReason "Broken" -CategoryTargetName "What" -CategoryTargetType "Something"
        Write-Warning "$MessageTxt 2"
        Write-Host "$MessageTxt 3"
        Write-Debug "$MessageTxt 4" 
        Write-Verbose "$MessageTxt 5"         

        Invoke-PostWrite -MessageText "$MessageTxt 5" -ClearLogFile $False -CheckLogFile $False | Out-Null

        $FoundNum = Invoke-LogLevelResults -LogMessage $MessageTxt

        If ($FoundNum -eq 1) {
            $TestFailed = $False
        }
        
        $TestFailed | Should Be $False
    }
}

# Run this one more time incase there was an error and it didn't stop
$ErrorActionPreference = "SilentlyContinue"
Try {
  Stop-Transcript |Out-Null
}
Catch [System.InvalidOperationException]{}
Remove-Item -Path $Script:TestLogForTranscript | Out-Null
Remove-Item -Path $Script:LogFile | Out-Null
$ErrorActionPreference = "Default"