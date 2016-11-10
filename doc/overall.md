
# Historical geocoding # 
------------------------

## Abstract ##

We document the historical geocoding project.
The goal is to start from an adress and a date (text),
and return the probable geolocalisation of this adress, along with confidence.


We propose a 3 parts workflow : 
 - First we deal with the input adress and date to analyse it and normalise it
 - then we compare the normalised adress with a previously created adress database
 - the found adresses are ranked according to various criterias
 
The workflow is illustrated and detailed in the folder `.\concept`.


## This doc organisation ##
This doc is organised around the workflow schema in the `.\concept` folder.
The schema is a functionial schema, where each functional part is numbered and detailed along the 
different level of doc (1 to 3)
	
	
##  Documentation of the workflow ##

### Level 1 ###
We propose a 3 parts workflow : 
(See schema `./concept/workflow_concept_L1_example.png`)

 - Part 1. We deal with the input adress and date to analyse it and normalise it.
	By normalising we mean separate the various fields of an adress to get a structured adress.
 - Part 2. We compare the normalised adress with a previously created normalised adress database.
	The comparison is a fast (indexed) multicriteria comparison. 

	The major challenge of this part is to build this normalised database from incomplete and heterogeneous data.
 - Part 3. The found adresses are ranked according to various criterias, displayed
	, and can be edited by users.
	
	
### Level 2 ###
More details on the 3 parts:
- Part 1
 * starts from a query adress containing a date
 * 1.1 Normalise this adress and date (extract structured information)
 * 1.2 Match differnt part of adress and date to the adress database, in an indexed way
- Part 2
 * The base material is scan of historical maps with estimated time windows
 * 2.4-6 Information about street geometry, street name and building number are extracted 
   from scanned maps, be it automatically or manually
 * 2.1-2 Using a template database schema, the adress database is constructed from 
   the (partial) information available
 * 2.3 Several tools (automatic and user assisted) allow to validate (and correct) 
   the database
- Part 3
 * 3.0-1 the found results are filtered and ranked according to default or user metrics
 * 3.2 The results are displayed in a GUI
 * 3.3 The user can edit the results, or enrich the database if the results 
   are partial/missing

			   
### Level 3 (detailed) ###
- Part 1
	* starts from a query adress containing a date
	* 1.1 Normalise this adress and date (extract structured information)
	* 1.2 Match differnt part of adress and date to the adress database, in an indexed way
- Part 2
	* The base material is scan of historical maps with estimated time windows
	* 2.6 User manually create vectors containg street axis, street name, 
	    and possibly building number
	* 2.4 Information (street surface, building number) are extracted from 
		scanned historical maps. 
	* 2.5 Extracted information is partial and sometime false, it must be consolidated
		 For instance extracted numbers must be successive.
	* 2.1 A normalised adress database structure is defined by analysing the existing norm for
		non historical database, various geocoders, and the specific needs of historical adress
	* 2.2 An historical database is created using the norms and the available data.
		Database creation must deal with partial information
	* 2.3 Several tools (automatic and user assisted) allow to validate (and correct) 
	   the database 
- Part 3
	This part is focused on the potential results obtained by matching the input adress with the adress database
	* 3.1 the found results are filtered and ranked according to default or user metrics
	* 3.2 The results are displayed in a GUI
	* 3.3 The user can edit the results, or enrich the database if the results 
	   are partial/missing
	
### Level 4 (Full) ###
- Part 1
	* This part start with a query adress and a date, provided by a user or via an automated mechanism (batch mode)
	* 1.1 Normalise
	* 1.1.1 If the query adress directly contains the adress and the date, the date and adress are separated.
		We use regular expression to do so.
		Missing date are handled at this level (a default 1850 date is added)
	* 1.1.2 Parse and normalise adress and date
		- 1.1.2.1 We parse/normalise adress using the `libpostal` tool. `libpostal` is a machine learning method trained on open street map
			dataset to parse french adress into structured content. In our case, it can separate the numbering part, the way part, and the city part.
		- 1.1.2.2 The date is parsed/normalised using the python module `dateutil` and regexp
		- 1.1.2.3 In France the numbering may contain more than number, for instance '12 Bis'. We parse and normalise that using regexp.
			This has been tested and validated for the whole Paris open street map current data.
	* 1.2 Match the different element to adress database
		- 1.2.3 match numbering to adress database. Numbers are matched using a simple int to int distance modified to take into consideration the parity.
			For instance the int distance between 12 and 13 is 1, but in fact 12 is more likely to be closer to 14 if 12 is missing.
			Anyway the classical btree index allow efficient knn queries, but is not really needed, as the match happens first through way name,
			and the number of numbering per way is limited.
		- 1.2.1 We match the query way to the database way. It is text to text matching, in a robust way. We have several robust solutions to this end,
			such as the trigram approach. We use the `pg_trgm` extension for fast indexed robust comparison between text.
		- 1.2.2 Historical dates are in fact fuzzy. We choose to model the fuziness using the trapezoidal model.
			A new postgres data type is created accordingly, with cast to range and to postgis geometry. This allows for several indexes for fast and robust
			fuzzy time distance. The fuzzy distance operator we use is custom. 
- Part 2
	* This part starts with scan of historical maps with estimated time windows
	* 2.6 User manually create vectors containg street axis, street name, 
	    and possibly building number
		- 2.6.1 A precise list of available vectorised information is made. Data vectorisation source is known. All the available data is physically retrieved and put on a shared filesystem
		- 2.6.2 The completeness and accuracy of data is evaluated and mapped. 
	* 2.4 Information (street surface, building number) are extracted from 
		scanned historical maps. 
		- 2.4.1 The street surface is extracted from scanned maps. We tested several methods that may be used depending on the type of scanned map.
			The more user friendly is probably to use a watershed algorithm on a super pixeled map to limit overflow. 
			The user has the task to manually complete the missing building border in a vecctorised way 
			(i.e. clicking new lines to complete building borders with holes).
			A full automatic solution could be reached using graphcut. The users would be tasked to ad points inside building if necessary.
		- 2.4.2 The building numbers are extracted. This task is complex to automate. We explored two kind of solution.
			The fist one is to use machine learning trained on on had-written digits database, and then slide a window along the scanned map to find all digits.
			Then another complex process has to merge the digits into numbers.
			The second solution is to extract numbers by image processing, by hypothesing that digits are isolated object of a given interval of connected pixels.
			The results is a set of small image representing numbers. The number must still be extracted from this images using OCR.
	* 2.5 Extracted information is partial and sometime false, it must be consolidated
		- 2.5.1 Consolidate street surface. The street surface can be consolidated by checking that found street surface is not too far from street axis, for instance.
		- 2.5.2 Consolidate building numbers. We leverage the prior knwoledge about numbering, such as the number should be in growing number, and ordering scheme is
			defined in Paris by the Seine river. 
	* 2.1 A normalised adress database structure is defined by analysing the existing norm for
		non historical database, various geocoders, and the specific needs of historical adress
		- 2.1.1 We define an extension for postgres than contains the template tables and functions for historical geocoding. 
			Then various data can be added to this tables virtually by usign the postgres inheritance mechanism.
		- 2.1.2 Custom import scripts are created to be adapted to the already existing vectorised data. 
	* 2.2  An historical database is created using the norms and the available data.
		- 2.2.0 The historical database is indexed so fast match is possible
		- 2.2.1 Because information is more often than not partial (in perticular regarding the building numbers),
			building number extrapolation is needed, both spatially and temporally.
			We have two potential tools to adress this extrapolation. The first one is 'gaussian process', which seems 
			well adapted to spatial extrapolation and integrating prior knowledge on Paris spacing between numbers.
			The second tool is Hidden markow chain, and graphical model in general. They could be used to leverage the 
			knowledge contained by the evolution of distances between numbers learned on current numbers. 
		- 2.2.2 The database is enriched with features that allow for felxibility in futur type of input data, that track edit and 
			that deal with aliases for adress. 
	* 2.3 Several tools (automatic and user assisted) allow to validate (and correct) 
	   the database.
		- 2.3.1 Semantic incoherencies are detected along the names of way. For instance pa way must be continuous (excepting places/roundabouts),
			and all different parts should have the exact same semantic (`rue de la paix`, `r. de la paix`, `r.de.la.paix`, `rue_de_la_paix`).
			These incoherencies are detected and plotted, so a user can correct them.
		- 2.3.2 The incoherencies in building numbers are detected and displayed so they can be corrected. Numbers should be growing, 
			their parity depending on the side of the way most of the time. The growing pattern is defined by the Seine river. 
			Missing numbers are also plotted. 
- Part 3 
	* This part is focused on the potential results obtained by matching the input adress with the adress database
	* 3.1 the found results are filtered and ranked according to default or user metrics
		- 3.1.1 We use the user defined metric to perform so. The user can combine metric on time, semantic, and possibly distance to a user defined area
		- 3.1.2 In a batch perspective, we used a predefined criteria merging different metrics to return only the best result if enough , or nothing.
	* 3.2 The results are displayed in a GUI
		- 3.2.1 The display interface is web based so it can be used by non-GIS people. 
			It contains a way to see historical maps as background, various historical road network, and various building numbers.
			Another part is dedicated to entering the query adress and query date.
			Another part is dedicated to listing the results along with ordering the results with various metrics.
			A last part display the normalised form / prefered alias of the best result.
		- 3.2.2 The user as access to a REST API that allow to programmatically 
			send adress and date query and retrieve best result.
			A very simple php page is sufficient to create a REST api, as long as the 
			adressing functionnality are contained within the database.

	* 3.3 The user can edit/enrich the database.
		First the user can add / move building numbers, and change to which way the numbers are associated.
		The numbers date might alos be changed
		Second the user can change the geometry and semantic of the way.
		LAst the user can edit adress aliases.
		We plan to use in-base interaction, as in remi thesis (inverse_procedural_street_modelling, github, chapter 4)
	
	
