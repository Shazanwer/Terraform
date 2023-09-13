WSMAN helper
------------
Connect-WSMan -ComputerName "sha1" -Port 5985
cd wsman:
Disconnect-WSMan -ComputerName "sha1" 
Restart-Service WinRm
Get-Service WinRM
Winrm get winrm/config/service/Auth

For Terraform Debugging
------------------------
export TF_LOG = "DEBUG"
export TF_LOG_PATH = "C:\terraform\Logs\terraform.log"