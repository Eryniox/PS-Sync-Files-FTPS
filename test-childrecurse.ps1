#Requires -Version 5
> $child | Export-Clixml -Path c:\temp\test.clixml
> $childall =@()
> cd ..
> cd ..
> cd .\03-Lib\
03-Lib> cd ..
> $child1 =Get-ChildItem  .\03-Lib\ -Recurse
> $child2 =Get-ChildItem  .\04-Lib\ -Recurse
> $child3 =Get-ChildItem  .\09-Lib\04\ -Recurse
> $child4 =Get-ChildItem  .\09-Barn\03\ -Recurse
> $childall += $child1
> $childall += $child2
> $childall += $child3
> $childall += $child4
> $childall.Count
20474
> $childall | Export-Clixml -Path c:\temp\test-FULL.clixml
#https://docs.microsoft.com/en-us/dotnet/api/system.io.directory.enumeratefiles?redirectedfrom=MSDN&view=net-5.0#overloads
#https://stackoverflow.com/questions/7196937/how-to-speed-up-powershell-get-childitem-over-unc
