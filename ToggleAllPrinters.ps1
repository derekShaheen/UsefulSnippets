## Intended to loop through all printers on a system and pause or resume the spooling.

# Get all installed printers
$action = "pause" # or "resume"
$printers = Get-WmiObject -Query "SELECT * FROM Win32_Printer"

# Iterate through each printer
foreach ($printer in $printers) {
    $printerName = $printer.Name

    if ($action -eq "pause") {
		# Pause the printer
        Write-Host "Pausing printer: $printerName"
        (get-wmiobject win32_printer -filter "name='$printerName'").pause()
        (Get-WmiObject -Query "SELECT * FROM Win32_Printer WHERE Name = '$printerName'").Put()

    } else {
        # Unpause the printer
        Write-Host "Unpausing printer: $printerName"
        (get-wmiobject win32_printer -filter "name='$printerName'").Resume()
        (Get-WmiObject -Query "SELECT * FROM Win32_Printer WHERE Name = '$printerName'").Put()
    }
}
