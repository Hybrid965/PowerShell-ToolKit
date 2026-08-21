# Filter by department, Select Name, Department and User Email. 

Get-ADUser -Filter {Department -like "Sales*"} -Properties Department, Description | 
Select-Object Name, Department, Description, UserPrincipalName 