#----------------------------------------------------------------------------------------------------------------------------------
# Script  : createArchive.ps1
#----------------------------------------------------------------------------------------------------------------------------------
# Author  : Denis Lambret
# Date    : 31.03.2022
# Version : 0.1
#----------------------------------------------------------------------------------------------------------------------------------
# Command parameters
# -path : Log input directory to process (no file given in reference)
#----------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------
# Synopsys
#----------------------------------------------------------------------------------------------------------------------------------
#
#----------------------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------------------------------------
#                                  INITALIZATION + CMD PARAMETERS
#----------------------------------------------------------------------------------------------------------------------------------
Param(
    [Parameter(Mandatory)][string] $path,
    [switch] $recurse,
    [switch] $remove
)

BEGIN {
    #.............................................................................................................................
    # Update vars depending of environment used
    $Env:PSModulePath = $Env:PSModulePath+";D:\dev\40_PowerShell\tcs\libs"
    $log_path = "D:\dev\40_PowerShell\tcs\logs"

    # $Env:PSModulePath = $Env:PSModulePath+";Y:\03_DEV\06_GITHUB\tcs-1\libs"
    # $log_path = "Y:\03_DEV\06_GITHUB\tcs-1\logs"

    Import-Module libLog
    if (-not (Start-Log -path $log_path -Script $MyInvocation.MyCommand.Name)) { exit 1 }
    $rc = Set-DefaultLogLevel -Level "INFO"
    $rc = Set-MinLogLevel -Level "DEBUG"
}


#----------------------------------------------------------------------------------------------------------------------------------
#                                                 G L O B A L   V A R I A B L E S
#----------------------------------------------------------------------------------------------------------------------------------
PROCESS { 
    $VERSION = "0.1"
    $AUTHOR  = "Denis Lambret"
    $SEP_L1  = '-------------------------------------------------------------------------------------------------------------------------------------------------------------------'
    $SEP_L2  = '...................................................................................................................................................................'
    $EXIT_OK = 0
    $EXIT_KO = 1

#----------------------------------------------------------------------------------------------------------------------------------
#                                                             M A I N
#----------------------------------------------------------------------------------------------------------------------------------
    log -Level Info -Message ( $MyInvocation.MyCommand.Name + " v" + $VERSION + "    " + $AUTHOR)
    log -Level Info -Message $SEP_L1 
    if (-not (Test-Path $path)) {
        log -Level "FATAL" -Message ("GET - Input directory " + $path + " not found! Abort...")
    } 

    # Create log list, group by date et log process name
    log -Level "INFO" -Message "GET - Build log files list from $path using filter *.log"
    $fullList = New-Object -TypeName 'System.Collections.ArrayList'
    
    if ($recurse) {
        $list = Get-ChildItem -Path $path -Filter *.log
    } else {
        $list = Get-ChildItem -Path $path -Filter *.log -Recurse -Force
    }
    
    ForEach ($item in $list)
    {
        $groupName = ''
        $rc = $item.name | select-string -Pattern '^(\d{8})_(\d+)_(.*).log$' -AllMatches
        
        if ($rc) {
            $date_stamp        = $rc.Matches[0].Groups[1].Value
            $time_stamp        = $rc.Matches[0].Groups[2].Value
            $application_name  = $rc.Matches[0].Groups[3].Value
            $date_real         = [Datetime]::ParseExact($date_stamp, 'yyyyMMdd', $null)
            $year              = Get-Date $date_real -Format "yyyy"
            $month             = Get-Date $date_real -Format "MM"
            $day               = Get-Date $date_real -Format "dd"
        } else {
            $rc = $item.name | select-string -Pattern '^(\d{8})_(.*).log$' -AllMatches
            if ($rc) {
                $date_stamp        = $rc.Matches[0].Groups[1].Value
                $time_stamp        = $null
                $application_name  = $rc.Matches[0].Groups[2].Value
                $date_real         = [Datetime]::ParseExact($date_stamp, 'yyyyMMdd', $null)
                $year              = Get-Date $date_real -Format "yyyy"
                $month             = Get-Date $date_real -Format "MM"
                $day               = Get-Date $date_real -Format "dd"
            }
        }
          
        $groupName = $rc.Matches[0].Groups[3].Value
        $item | Add-Member -Name "objGroup" -Type NoteProperty -value $groupName
        $item | Add-Member -Name "year" -Type NoteProperty -value $year
        $item | Add-Member -Name "month" -Type NoteProperty -value $month
        $item | Add-Member -Name "day" -Type NoteProperty -value $day
        $idx = $fullList.add($item)
    }

    $fulllist = $fulllist | Group-Object -Property year, month, objGroup | Sort-Object -Property year,month, objGroup

    # Create the archive
    Push-Location
    Set-Location $path
 
    $fullList | foreach-object {
    $rc = $_.Group.Name | select-string -Pattern '^(\d{8})_(\d+)_(.*).log$' -AllMatches
    if ($rc) {
            $date_stamp        = $rc.Matches[0].Groups[1].Value
            $time_stamp        = $rc.Matches[0].Groups[2].Value
            $application_name  = $rc.Matches[0].Groups[3].Value
            $date_real         = [Datetime]::ParseExact($date_stamp, 'yyyyMMdd', $null)
            $year              = Get-Date $date_real -Format "yyyy"
            $month             = Get-Date $date_real -Format "MM"
            $day               = Get-Date $date_real -Format "dd"
            $archive_path      = $path + "\archives\" + $year + "\" + $month 
            
            if (-not (Test-path $archive_path)) {
                log -Level "INFO" -Message ("SET - Create target archive directory : " + $path + "\" + $year + "\" + $month)
                New-item -Path $archive_path -ItemType Directory | Out-Null
            }
        } else {
            $rc = $item.name | select-string -Pattern '^(\d{8})_(.*).log$' -AllMatches
            if ($rc) {
                $date_stamp        = $rc.Matches[0].Groups[1].Value
                $time_stamp        = $null
                $application_name  = $rc.Matches[0].Groups[2].Value
                $date_real         = [Datetime]::ParseExact($date_stamp, 'yyyyMMdd', $null)
                $year              = Get-Date $date_real -Format "yyyy"
                $month             = Get-Date $date_real -Format "MM"
                $day               = Get-Date $date_real -Format "dd"
                $archive_path      = $path + "\archives\" + $year + "\" + $month 
            }
        }
            
        #"SET - Adding file -> " + $_.Group.Name 
        $dest = $archive_path + "\" + ( $year + $month + "_" + $application_name + ".zip") 
        if (-not (Test-Path $dest)) {
            log -Level "INFO" -Message ("SET - Create archive " + $dest + " and adding " + ($_.Group.Name).Count + " file(s) ")
        } else {
            log -Level "INFO" -Message ("PATCH - Update archive " + $dest + " by adding " + ($_.Group.Name).Count + " file(s) ")
        }
        $rc = Compress-Archive -Path ($_.Group.Name) -DestinationPath ($dest) -Update -CompressionLevel Optimal -ErrorAction SilentlyContinue
        if ($remove) {$_.Group.Name | ForEach-Object { Remove-Item ($path + "\" + $_)}}

    }
    Pop-Location
    log -Level Info -Message ($SEP_L1)
    Stop-Log
}

