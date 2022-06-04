param([int]$Intensity = 15)

$dayCounter = -400
$url = "http://web.contoso.com"
$success = 0
$failure = 0
for ($x = 0; $x -lt $Intensity; $x++) {

    $temp = Get-Random -Minimum -200 -Maximum 200
    $dayCounter += 1
    $date = (Get-Date).AddDays($dayCounter).ToString("yyyy-MM-dd") 
    $body = @{ temp = $temp; date = $date }
    
    try {
        Invoke-RestMethod -UseBasicParsing -Uri ($url + "/WeatherForecast") -Body ($body | ConvertTo-Json) -Method Put -ContentType "application/json"
        $success += 1 
    }
    catch {
        try {
            Invoke-RestMethod -UseBasicParsing -Uri ($url + "/WeatherForecast/$date") -Method Get -ContentType "application/json"
        }
        catch {
            $failure += 1
        }       
    }
}

Write-Host "Result Success: $success Failure: $failure"