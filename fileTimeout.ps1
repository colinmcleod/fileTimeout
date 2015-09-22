﻿<#	
	.NOTES
	===========================================================================
	 Created on:   	9/21/2015
	 Created by:   	Colin McLeod
	 Filename:      fileTimeout.ps1
	 Version:		0.0.8
	===========================================================================
	.DESCRIPTION
		This module was written to suplement custom backup scripts, unfortunately, scripts required to replace unreliable proprietary vendor backup processes. 
		
		With the goal of adding:

		- Performance measuring
		- Timeout
		- Logging
		- Error notification
		- Wait till the file(s) are no longer locked

		While keeping it as generic as possible for future reuse.

		It checks a specified directory for the existence of specified number of files for a specified number of loops and seconds per loop. Then waits till all files are available for R/W.
	
	.USAGE
	
	fileTimeout -Path <path> -Seconds <0-99999999> -LoopThreshold <0-99999999> -FileThreshold <0-99999999> -LogPath <path>

	-Path
		The path you want to check, e.g. C:\Backup\App

		Default value: C:\Backup

	-Seconds
		The number of seconds you want the script to wait between checks, e.g. 20 seconds w/ 6 loops will have the script run for 2 minutes if it never finds files.

		Default value: 60

	-LoopThreshold
		Indicates the number of loops to perform before timeout, e.g. 50 will loop the check 50 times, 50 directory reads.

		Default value: 5

	-FileThreshold
		Indicates the number of files to find to report Success, e.g. if 5 files are expected to exist and it never finds 5 files it will report failure.

		Default value: 1

	-LogPath
		The path you want the log to write to, e.g C:\var\logs\myapp\log.txt

		Default value: 

	.EXAMPLE

	fileTime -Path \\server\files -Seconds 180 -LoopThreshold 10 -FileThreshold 2 -LogPath C:\logs\mylog.log

	fileTime D:\Files 60 5 2

#>

function fileTimeout
{
	
	# --- Function Parameters --- #
	
	Param (
		[string]$Path,
		[string]$Seconds,
		[string]$LoopThreshold,
		[string]$FileThreshold,
		[string]$LogPath
	)
	
	# --- Global Variables --- #
	
	$logStamp = Get-Date -Format 'mm.dd.yyyy hh:mm:ss tt'
	$loopCount = 0

	# --- Error & Log Handling --- #
	
	function IsNull
	{
		if (!$objectToCheck)
		{
			return $true
		}
		
		if ($objectToCheck -is [String] -and $objectToCheck -eq [String]::Empty)
		{
			return $true
		}
		
		if ($objectToCheck -is [DBNull] -or $objectToCheck -is [System.Management.Automation.Language.NullString])
		{
			return $true
		}
		
		return $false
	}
	
	function logWrite
	{
		Param ([string]$logstring)
		
		$ifNull = IsNull($LogPath)
		
		If ($ifNull -eq $true)
		{
			$logFolder = "C:\logs"
			$logFile = "Powershell_fileTimeout_$($date).log"
			$LogPath = $logFolder + $logFile
			
			New-Item $logFolder -ItemType directory -ErrorAction SilentlyContinue
			New-Item $LogPath -ItemType file -ErrorAction SilentlyContinue
			
			Add-content $LogPath -value $logstring
		}
		Else
		{
			New-Item $LogPath -ItemType file -ErrorAction SilentlyContinue
			
			Add-content $LogPath -value $logstring
		}
		
	}
	
	function fileLock
	{
		param ([string]$filePath)
		
		$filelocked = $false
		$fileInfo = New-Object System.IO.FileInfo $filePath
		trap
		{
			Set-Variable -name Filelocked -value $true -scope 1
			continue
		}
		$fileStream = $fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		if ($fileStream)
		{
			$fileStream.Close()
		}
	}
	
	function sendMail
	{
		
		# --- Set Mail Variables --- #
		
		$From = "CDR Micros Backup <no-reply@cnty.com>"
		$To = "CDR IT <colin.mcleod@cnty.com>"
		$smtp = "mail.cnty.io"
		
		# --- Log this action --- #
		
		logWrite = "$($logStamp): Email Notification"
		logWrite = "From: $($From)"
		logWrite = "To: $($To)"
		logWrite = "Subject: $($Subject)"
		
		$Body = Get-Content $logfile
		$Attachement = $logfile
		
		# --- Send Message --- #
		
		Send-MailMessage -From $From -To $To -subject $Subject -Body $Body -Attachments $Attachment -Priority High -DeliveryNotificationOption None -smtpServer $smtp
	}
	
	
	# --- Loop, Count, and Timeout --- #
	
	Do
	{
		
		$loopCount++
		
		logWrite "$($logStamp): Looped $($loopCount) times."
		
		Start-Sleep -s $Seconds
		
		$fileCount = (Get-ChildItem -Path $Path | Measure-Object).Count
			
		If ($loopCount -ge $LoopThreshold)
		{
			$Subject = ""
			sendMail
			Exit
		}
	}
	Until ($fileCount -ge $FileThreshold)
	
	logWrite "$($logStamp): Found $fileCount files in specified directory."

	$files = Get-ChildItem -Path $Path -Recurse
	
	foreach ($file in $files)
	{
		$fileLock = fileLock $file
		
		If ($fileLock -eq $true)
		{
			logWrite "$($logStamp): Locked file found in directory - $($file.Name)"
		}
		Else
		{
			logWrite "$($logStamp): File found in directory - $($file.Name)"
		}
		
		Do
		{
		fileLock $file
		}
		Until ($filelocked -eq $false)
	}
	
	logWrite "$($logStamp): File Verification Complete."
}