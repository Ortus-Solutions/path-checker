<cfscript>
  options = {
    fileFilter = "cfm,cfc,css,js"
  };

  //Get Current Directory
  currentDir = GetDirectoryFromPath(GetCurrentTemplatePath());
  currentDir = left(currentDir,len(currentDir)-1); //Remove Last Slash

  if(!StructKeyExists(session, "fullDirIndex"))
    session.fullDirIndex = DirectoryList(currentDir,true,"query");
  fullDirIndex = session.fullDirIndex;
</cfscript>

<!--- Filter Query Into Root & All Paths --->
<cfquery name = "rootFolders" dbtype="query">
    select *
    from fullDirIndex
    where directory = '#currentDir#'
</cfquery>
<cfquery name = "allPaths" dbtype="query">
    select directory, name, directory + '/' + name as dirPath
    from fullDirIndex
    where type = 'Dir'
    order by dirPath Desc
</cfquery>
<cfquery name = "allFiles" dbtype="query">
    select *
    from fullDirIndex
    where type = 'File' and (
      <cfloop list="#options.fileFilter#" index="fExt">
        name like '%#fExt#' or
      </cfloop>
      1 = 0
    )
</cfquery>
<!--- Generate Regex String --->
<!--- This will match any link surrounded by "" '' () and containing one of the root folders --->
<cfsavecontent variable="strRegEx">
  (?i)([\w]+)=?['"\(]([^\s'"\(]*?(<cfoutput>#valueList(rootFolders.name,"|")#</cfoutput>)/[^\s'"\)]*?)['"\)]
</cfsavecontent>

<cfscript>
pathArray = [];
for(row in allPaths) arrayAppend(pathArray, replace(row.dirPath,currentDir,"","All") & "/");
pathList = arrayToList(pathArray);

allDirList = valueList(allPaths.name); //QuickIndex For Search
allDirLookup = {}; //Path Associated with folder
for(row in allFiles) allDirLookup[row.name] = row.directory & "/" & row.name;



unmatched = {};
fixerUppers = {};

function processCaseIssue(foundFilePath){
  matchedArr = ListToArray(listGetAt(pathList,listFindNoCase(pathList,foundFilePath)),'/');
  fpArr = ListToArray(foundFilePath,'/');
  DiffString = "";

  //Build Path String with Corrections
  for(i=1;i<=arrayLen(matchedArr);i++){
    if(Compare(matchedArr[i],fpArr[i]) eq 0){
      DiffString &= '<font color="green">' & fpArr[i] & "/</font>";
    } else {
      DiffString &= '<font color="red">' & fpArr[i] & " => <strong>"& matchedArr[i] & "</strong>/</font>";
    }
  }
  if(!StructKeyExists(fixerUppers, DiffString)){
    fixerUppers[DiffString] = {count= 0, path= foundFilePath, ext={}, linkType={}};
  }
  fixerUppers[DiffString].count++;
  fixerUppers[DiffString].ext[ListLast(row.name,".")] = true;
  fixerUppers[DiffString].linkType[linkType] = true;
}

function RelativeFileExists(filePathArr,parentFileDir,fileName){
  dirGuess = "";
  if(arrayLen(filePathArr) && structKeyExists(allDirLookup,filePathArr[1])){
    dirGuess = allDirLookup[filePathArr[1]];
  }
  if(FileExists(dirGuess & "/" & urlFindName)) return true;
  if(FileExists(row.directory  & "/" & urlFindName)) return true;
  return false;
}

for(row in allFiles){
   fileName = row.directory & "/" & row.name;
   // Read In File
   newfile = FileRead(fileName);

   // Execute Regex Matcher
   objPattern = CreateObject("java", "java.util.regex.Pattern").Compile(JavaCast( "string", Trim( strRegEx ) ));
   objMatcher = objPattern.Matcher( JavaCast( "string", newfile ));

   if(objMatcher.find()){
      while (objMatcher.find()){
          linkType = objMatcher.group(JavaCast( "int", 1 )); //First Group Attrib Name (src, link, url, template, etc.)
          linkUrl = objMatcher.group(JavaCast( "int", 2 )); //Url Inside the quotes

          foundUrl = rereplace(linkUrl,"^(?:https?:\/\/)?(?:[^@\n]+@)?(?:www\.)?([^:\/\n]+)","","All"); //Make Path Relative
          foundFilePath = GetDirectoryFromPath(foundUrl); //Get URL Directory
          urlFindName = GetFileFromPath(linkUrl); //Get Url File Name

          //Remove Sourrounding Slashes
          stripfoundFilePath = rereplace(foundFilePath,"^[^A-Za-z0-9]+","","All");
          stripfoundFilePath = rereplace(stripfoundFilePath,"[^A-Za-z0-9]+$","","All");

          if(listFind(pathList,foundFilePath) > 0){
            // If this matches we know the path is ok
          } else if(listFindNoCase(pathList,foundFilePath) > 0){
            // We have a correct path but a case sensitivity issue
            processCaseIssue(foundFilePath);
          } else {
            // No paths found exact or case insentive. now we deconstruct the path
            // and try to match folders to what is avaliable in the directory
            fpArr = ListToArray(stripfoundFilePath,'/');
            if(RelativeFileExists(fpArr,row.directory,urlFindName)) continue;

            DiffString = "";
            for(i=1;i<=arrayLen(fpArr);i++){
              if(listFind(allDirList,fpArr[i]) gt 0){
                DiffString &= '<font color="green">' & fpArr[i] & "/</font>";
              } else if (listFindNoCase(allDirList,fpArr[i]) gt 0){
                DiffString &= '<font color="red">' & fpArr[i] & " => <strong>"& listGetAt(allDirList,listFindNoCase(allDirList,fpArr[i])) & "</strong>/</font>";
              } else {
                DiffString &= '<font color="">' & fpArr[i] & "/</font>";
              }
            }
            if(!StructKeyExists(unmatched, linkUrl)){
              unmatched[linkUrl] = {
                file = replace(fileName,currentDir,"","All"),
                diff = DiffString,
                path= foundFilePath,
                linkType= linkType
              };
            }

          }

      }
   }
 }

//Display the results

WriteOutput("<h2>Case Issue</h2>");
WriteOutput("<table border=1 cellpadding=4>");
  WriteOutput("<tr>");
  WriteOutput("<th>File Path  (Correct Folder Name)</th>");
  WriteOutput("<th>Occurances</th>");
  WriteOutput("<th>Source Path</th>");
  WriteOutput("<th>Attribs</th>");
  WriteOutput("</tr>");
for(item in StructSort(fixerUppers, "numeric", "Desc","count")){
  WriteOutput("<tr>");
  WriteOutput("<td>" & item & "</td>");
  WriteOutput("<td>" & fixerUppers[item].count & "</td>");
  WriteOutput("<td>" & StructKeyList(fixerUppers[item].ext, ", ") & "</td>");
  WriteOutput("<td>" & StructKeyList(fixerUppers[item].linkType, ", ") & "</td>");
  WriteOutput("</tr>");
}
WriteOutput("</table>");


WriteOutput("<h2>Unmatched</h2>");
WriteOutput("<table border=1 cellpadding=4>");
WriteOutput("<tr>");
  WriteOutput("<th>Source File</th>");
  WriteOutput("<th>FilePath</th>");
  WriteOutput("<th>Attribute name</th>");
  WriteOutput("<th>Fuzzy Folder Match</th>");
WriteOutput("</tr>");
for(item in unmatched){
  WriteOutput("<tr>");
    WriteOutput("<td>" & unmatched[item].file & "</td>");
    WriteOutput("<td>" & item & "</td>");
    WriteOutput("<td>" & unmatched[item].linkType & "</td>");
    WriteOutput("<td>" & unmatched[item].diff & "</td>");
  WriteOutput("</tr>");
}
WriteOutput("</table>");

</cfscript>
