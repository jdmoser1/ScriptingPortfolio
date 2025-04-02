# Templates 

I use some of the files from this folder whenever I start a new PowerShell project. A typical project will include a module file,  `.json`, and procedure script. 

Functions in the module are written as proper cmdlets, so an experienced user may import the module directly, or through the procedure script. 

## `Template.psm1`

This is the template for any new modules. This will contain any classes, support functions (mostly intended to be used inside the module only), and public functions (which are available for the user or depending scripts). The template module is usually dependent on the `.json` with the same name. 

## `Template.json` 

This `.json` contains variables that persist between PowerShell sessions. I avoid calling the configuration "constants" because I may create functions to update and write the configuration back to the `.json`. An experienced user may change this file directly. 

## `TemplateProcedure.ps1` 

This is a script that is designed to complete a specific task, though most often I allow Parameters so we can vary how the task is completed. This is usually dependent on the module file. 

For the purposes of having a demo, you can actually execute `TemplateProcedure.ps1` with the Path parameter. If you do, it will output the number of lines in each text file in the Path (Script Root by default), controlled by a "Filter" entry in the `.json`

## `TemplateFlat.ps1`

This is a template for a standalone or "flat" script. I may use this template when there's no need for modularity, or the script only does exactly one task one specific way. 

## `Extras.ps1` 

This file just has a couple of functions that may be helpful in some projects. 

