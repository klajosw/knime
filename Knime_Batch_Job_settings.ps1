#region Initial Setup ------------------------------------

$PWD = (Get-Item -Path ".\" -Verbose).FullName                                    #Gets the current Working Directory where the Powershell script is called from
$ThisScript = $PWD+"\"+$MyInvocation.MyCommand.Name                               #The name of this PowerShell script
$KnimeLog = "$PWD\Logs\"+$MyInvocation.MyCommand.Name+".log"                      #Runtime log for Powershell
$KnimeLogTrimmed = "$PWD\Logs\"+$MyInvocation.MyCommand.Name+".log.Trimmed"       #Runtime log trimmed to last 15 days
$StdOutLog = "$PWD\Logs\"+$MyInvocation.MyCommand.Name+".tmp"                     #Temp file to store Knime Runtime output to the console window.
$StdErrLog = "$PWD\Logs\"+$MyInvocation.MyCommand.Name+"_error.tmp"               #Temp file to store Knime Runtime Error output to the console window.
$KnimeExecPath = "c:\Program Files\KNIME\knime.exe"                               #Knime Runtime Instance

$KnimeWorkspacePath = "D:\KnimeWorkflows\Prod\knime-workspace"    #Knime Workspace which dictates the location of knime.log and log4j settings
$KnimeWorkspaceLog = "$KnimeWorkspacePath\.metadata\knime\knime.log"
$KnimeWorkflowParams =     '-workflow.variable=MY_DBURL,"\"jdbc:sqlserver://aws-myserver:1433;databaseName=PROD1;integratedSecurity=true;encrypt=false;\"",String' `
                        + ' -workflow.variable=CONTROLTABLE,"Table_Control_File",String'

#endregion