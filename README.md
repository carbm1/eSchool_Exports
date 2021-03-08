# eSchool_Exports

This script creates a Download Definition for the eSchool tables specified in the $tables variable.

The hard coded ones are @('REG','REG_STU_CONTACT','REG_CONTACT')

You can customize what tables you want in your export by specifying the $tables variable and dot sourcing the script.
````
$tables = @('REG','REG_STU_CONTACT','REG_CONTACT','REG_ACADEMIC','REG_BUILDING','REG_BUILDING_GRADE','REG_CONTACT_PHONE','REG_GRADE','REG_PERSONAL'))
. .\eSchool_Table_Exports.ps1 -username 0401cmillsap
````

Then you can run the Download Definition using the Scripts from the eSchoolUpload project then download the files.