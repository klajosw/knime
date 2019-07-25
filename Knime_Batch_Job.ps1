. .\Knime_Batch_Job_settings.ps1
Import-Module SQLPS -DisableNameChecking

#region Knime Workflows ------------------------------------
Function Main()
{

    Log "Script Started: <$ThisScript> ==========================================================================="
    Try
    {

        # Before we begin, trim Log File to Last 15 days
        Get-Content $KnimeLog | Where-Object { ( (Get-Date) - (Get-Date $_.Substring(0,10)) ).Days -le 15} | Add-Content $KnimeLogTrimmed
        Remove-Item $KnimeLog
        Rename-Item $KnimeLogTrimmed $KnimeLog 

        Log "====================================================================================================="
        Log "Trim Logfile Completed ==============================================================================="
        Log "====================================================================================================="

        
        Run-WorkFlow -WorkFlowPath "\mydirectory\myworkgroup\my work flow 1"
        Run-WorkFlow -WorkFlowPath "\mydirectory\myworkgroup\my work flow 2"
        Run-WorkFlow -WorkFlowPath "\mydirectory\myworkgroup\my work flow 3"


        Log "====================================================================================================="
        Log "Run Workflows Completed ======================================================================="
        Log "====================================================================================================="


    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        Send-MailMessage -From emailid@yourdomain.com -To @("emailid1@yourdomain.com", "emailid2@yourdomain.com") -Subject "Knime Script Failed - $ThisScript" -SmtpServer smtp.yoursmptp.com `
            -Body "Error Message: $ErrorMessage `r`nReview log file: $KnimeLog"
        Break
    }
    Finally
    {
        If($global:IgnoreExceptionFlag) {$MessageBody = "One or more errors were bypassed. To locate errors search for: ERRORBYPASSED "}
        $MessageBody +=  "Review log file: $KnimeLog"

        Send-MailMessage -From emailid@yourdomain.com -To @("emailid1@yourdomain.com", "emailid2@yourdomain.com") -Subject "Knime Script Completed - $ThisScript" -SmtpServer smtp.yoursmptp.com `
            -Body "`r`n$MessageBody"

        Log $MessageBody
        Log "Script Completed: <$ThisScript> ==========================================================================="
    }
}
#endregion




#region Functions ------------------------------------

function Log($string)
{
   $Now = Get-Date -format "yyyy-MM-dd HH:mm:ss"
   $string = $Now + " " + $string
   Write-Host $string
   add-content  $KnimeLog $string
}


function LogPipe()
{
   foreach($string in $input)
   {
	   $Now = Get-Date -format "yyyy-MM-dd HH:mm:ss"
	   $string = $Now + " " + $string
	   Write-Host $string
	   add-content  $KnimeLog $string
        
       If ($string.Contains("Error while adding row")) { #Using $global:KnimeWarningFlag variable here since Knime DBWriter errors are not being returned as an error from Knime, but only as a warning. So scraping the log file and throwing an error.
        $global:KnimeWarningFlag = $true
       }

       If ($string.Contains("Error while updating row")) { #Using $global:KnimeWarningFlag variable here since Knime DBUpdate errors are not being returned as an error from Knime, but only as a warning. So scraping the log file and throwing an error.
        $global:KnimeWarningFlag = $true
       }

   }
}

function Run-WorkFlow ($WorkFlowPath){

    $global:KnimeWarningFlag = $false
    $WorkFlowFullPath = $KnimeWorkspacePath + $WorkFlowPath

    Log "Initiating Worflow: <$WorkFlowFullPath> =========================="
    $KnimeArguments = '-data "'+$KnimeWorkspacePath+'" -consoleLog --launcher.suppressErrors -reset -nosplash -application org.knime.product.KNIME_BATCH_APPLICATION -workflowDir="'+$WorkFlowFullPath `
					    +'" '+$KnimeWorkflowParams
    Log "Knime Arguments: $KnimeArguments"
    $WorkflowProcess = Start-Process -filepath $KnimeExecPath -ArgumentList $KnimeArguments -passthru -wait -RedirectStandardOutput $StdOutLog -RedirectStandardError $StdErrLog
    $WorkflowProcessId = $WorkflowProcess.id
    $WorkflowExitCode = $WorkflowProcess.exitCode
    Get-Content $StdOutLog, $StdErrLog | LogPipe 
    Log "Completed Workflow <$WorkFlowFullPath> with return code: $WorkflowExitCode ================"
    
    <# Throw an application exception if Knime workflow returns an error code ($WorkflowExitCode)
       Or there is a Warning in the Knime Log file ($global:KnimeWarningFlag=True)
       But if the workflow path is one of these, only log the error and continue with rest of the script execution, do NOT throw an exception:
            \ERPDW Dynamics\Load Fact Tables*
            \ERPDW Dynamics\Deleted Rows*
    #>
    If (!($WorkflowExitCode -eq 0 -or $WorkflowExitCode -eq 1) -or ($global:KnimeWarningFlag)) { 
        $ErrorMessage = "Return Code for <$WorkFlowPath>: $WorkflowExitCode. Knime Warning Flag: $global:KnimeWarningFlag" 
        Log "Custom Exception: $ErrorMessage"

        If (($WorkFlowPath -like "*\ERPDW Dynamics\Load Fact Tables*") `
            -or ($WorkFlowPath -like "*\ERPDW Dynamics\Deleted Rows*")
           )
        {
            Log "ERRORBYPASSED for: <$WorkFlowFullPath>"
            $global:IgnoreExceptionFlag = $true
        }
        Else {
            Throw $ErrorMessage
        }
    }
}

#endregion





#region Reference ---------------------------------------
<#
Knime Return Codes
	EXIT_ERR_EXECUTION	4
	EXIT_ERR_LOAD	3
	EXIT_ERR_PRESTART	2
	EXIT_SUCCESS	0
	EXIT_WARN	1

Knime Arguments
	-vmargs -Dknime.logfile.maxsize=32m    #To limit logfile size

	
#>
#endregion



#region Testing -----------------------------------------
<#
$KnimeExecPath = "C:\Windows\System32\notepad.exe"
$KnimeArguments = "D:\KnimeWorkflows\Prod\knime-workspace\.metadata\knime\log4j3.xml"
$WorkflowProcess = Start-Process -filepath $KnimeExecPath -ArgumentList $KnimeArguments -passthru
$WorkflowProcessId = $WorkflowProcess.id
wait-process -id $WorkflowProcessId
$WorkflowExitCode = $WorkflowProcess.exitCode
$WorkflowExitCode 
#>
#endregion

#>


#Workaround for Bug in SQLPS
#CLS
D:
CD D:\KnimeBatchJobs\


#Global Variables
$ThisScript = $PWD+"\"+$MyInvocation.MyCommand.Name
$global:KnimeWarningFlag = $false
$global:IgnoreExceptionFlag = $false

# Remove Knime Logs if needed
#If (Test-Path $KnimeLog) { Remove-Item $KnimeLog }
#If (Test-Path $KnimeWorkspaceLog) { Remove-Item $KnimeWorkspaceLog }

Main  #Wrapping all the main code into this function and calling it here. This is a workaround to keep the main code up at the top of the script file.
