$path1 = "kombuwa_learning_screen.dart"
$c1 = Get-Content $path1 -Raw -Encoding UTF8
$c1 = $c1 -replace "Alapilla", "Kombuwa"
$c1 = $c1 -replace "alapilla", "kombuwa"
$c1 = $c1 -replace "ඇලපිල්ල", "කොම්බුව"
$c1 = $c1 -replace "\(ා\)", "(ෙ)"
$c1 = $c1 -replace "කා", "කෙ"
$c1 = $c1 -replace "මා", "මෙ"
$c1 = $c1 -replace "ගා", "ගෙ"
Set-Content $path1 $c1 -Encoding UTF8

$path2 = "letter_bubble_game_kombuwa.dart"
$c2 = Get-Content $path2 -Raw -Encoding UTF8
$c2 = $c2 -replace "Alapilla", "Kombuwa"
$c2 = $c2 -replace "alapilla", "kombuwa"
$c2 = $c2 -replace "ඇලපිල්ල", "කොම්බුව"
$c2 = $c2 -replace "\(ා\)", "(ෙ)"
$c2 = $c2 -replace '"කා", "මා", "ගා", "සා", "ලා", "බා", "තා", "දා"', '"කෙ", "මෙ", "ගෙ", "සෙ", "ලෙ", "බෙ", "තෙ", "දෙ"'
Set-Content $path2 $c2 -Encoding UTF8

$path3 = "word_start_letter_game_kombuwa.dart"
$c3 = Get-Content $path3 -Raw -Encoding UTF8
$c3 = $c3 -replace "Alapilla", "Kombuwa"
$c3 = $c3 -replace "alapilla", "kombuwa"
$c3 = $c3 -replace "ඇලපිල්ල", "කොම්බුව"
$c3 = $c3 -replace "\(ා\)", "(ෙ)"

$c3 = $c3 -replace "'පාට'", "'දෙක'"
$c3 = $c3 -replace "'_ ට'", "'_ ක'"
$c3 = $c3 -replace "'පා'", "'දෙ'"
$c3 = $c3 -replace "\['මා', 'පා', 'ගා', 'තා'\]", "['මෙ', 'දෙ', 'ගෙ', 'තෙ']"
$c3 = $c3 -replace "'assets/thumbnails/color.jpg'", "'assets/thumbnails/two.jpg'"

$c3 = $c3 -replace "'හාවා'", "'ගෙදර'"
$c3 = $c3 -replace "'_ වා'", "'_ දර'"
$c3 = $c3 -replace "'හා'", "'ගෙ'"
$c3 = $c3 -replace "\['හා', 'ගා', 'ලා', 'මා'\]", "['හෙ', 'ගෙ', 'ලෙ', 'මෙ']"
$c3 = $c3 -replace "'assets/thumbnails/rabit.jpg'", "'assets/thumbnails/house.jpg'"

$c3 = $c3 -replace "'මාමා'", "'තෙල්'"
$c3 = $c3 -replace "'_ මා'", "'_ ල්'"
$c3 = $c3 -replace "'මා'", "'තෙ'"
$c3 = $c3 -replace "\['තා', 'සා', 'මා', 'බා'\]", "['තෙ', 'සෙ', 'මෙ', 'බෙ']"
$c3 = $c3 -replace "'assets/thumbnails/uncle.jpg'", "'assets/thumbnails/oil.jpg'"

Set-Content $path3 $c3 -Encoding UTF8
