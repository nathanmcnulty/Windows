$OU = 'DN'
$bindAccount = 'Domain\User'
$owner = New-Object System.Security.Principal.NTAccount('Domain', 'User/Group')

(Get-ADObject -SearchBase $OU -SearchScope Subtree -LDAPFilter '(objectClass=computer)').DistinguishedName | ForEach-Object {
    $ACL = Get-Acl -Path "AD:\$_"
    $ACL.SetOwner($owner)
    Set-Acl -Path "AD:\$_" -AclObject $ACL
    $ACL.access | Where-Object { $_.IdentityReference -like "*$bindAccount*" } | ForEach-Object -Process { $ACL.RemoveAccessRule($_) } -End { $ACL | Set-Acl }
}