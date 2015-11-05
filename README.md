# path-checker
Path Checker

This can be added to any directory root and will check that all relative path urls in your codebase and verify that the path exists and is correctly cased.
After loading the page a list of items that failed either due to a case sensitivity issue or an invalid path will be shown.

Using this report runner is fairly easy.

 1. Add page to any projects root.
 2. Navigate to the page.
 3. View results.

There is also a options struct that you can change the file extentions you wish to search through.
 ```options = {
     fileFilter = "cfm,cfc,css,js"
   };```
