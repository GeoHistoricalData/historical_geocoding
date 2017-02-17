svar inputType = "string";
var stepped = 0, rowCount = 0, errorCount = 0, firstError;
var start, end;
var firstRun = true;
var maxUnparseLength = 10000;

$(function()
{
    $('.input-area').hide();
	// Tabs
	$('#tab-string').click(function()
	{
		$('.tab').removeClass('active');
		$(this).addClass('active');
		$('.input-area').hide();
		$('#input-string').show();
		$('#submit').text("Parse");
		inputType = "string";
	});

	$('#tab-local').click(function()
	{
		$('.tab').removeClass('active');
		$(this).addClass('active');
		$('.input-area').hide();
		$('#input-local').show();
		$('#submit').text("Parse");
		inputType = "local";
	});

	$('#tab-remote').click(function()
	{
		$('.tab').removeClass('active');
		$(this).addClass('active');
		$('.input-area').hide();
		$('#input-remote').show();
		$('#submit').text("Parse");
		inputType = "remote";
	});

	$('#tab-unparse').click(function()
	{
		$('.tab').removeClass('active');
		$(this).addClass('active');
		$('.input-area').hide();
		$('#input-unparse').show();
		$('#submit').text("Unparse");
		inputType = "json";
	});
	$('#view_result_in_tab').click(function()
	{
          //open a new tab with leaflet and appropriate ruid set
          //dislaying 
          url = "https://www.geohistoricaldata.org/interactive_geocoding/Leaflet-WFST/examples/geocoding.html?ruid="+ruid;
          win = window.open(url, '_blank'); 
          if (win) {
             //Browser has allowed it to be opened
            win.focus();
          } else {
            //Browser has blocked it
            alert('Please allow popups for this website');
          } 
          
	});
	$('#save_result_in_csv').click(function(){
           //getting the results from the rest api serveur, saving it as csv
           //updating ruid from the text field, if user inputted something
           ruid = document.getElementById('textRuid').value ; 
           getGeocodingJSONFromBase();
           textjson = ruid2json_result
           console.log("textjson",textjson);
           if(!textjson){
             alert("error : could'nt find results associated with ths ruid: "+ruid);
           }else{
             var text = Papa.unparse(textjson,{
              quotes: true,
              quoteChar: '"',
              delimiter: "|",
	      header: true,
	      newline: "\r\n"
             });
             var filename = $("#save_result_in_csv_text").val();
             var blob = new Blob([text], {type: "text/plain;charset=utf-8"});
             saveAs(blob, filename+".csv");
           }
	});

var l = $('#tab-local');
l.click();

	// Sample files
	$('#remote-normal-file').click(function() {
		$('#url').val($('#local-normal-file').attr('href'));
	});
	$('#remote-large-file').click(function() {
		$('#url').val($('#local-large-file').attr('href'));
	});
	$('#remote-malformed-file').click(function() {
		$('#url').val($('#local-malformed-file').attr('href'));
	});




	// Demo invoked
	$('#submit').click(function()
	{
		if ($(this).prop('disabled') == "true")
			return;

                document.getElementById("pbarDiv").hidden=false;
		stepped = 0;
		rowCount = 0;
		errorCount = 0;
		firstError = undefined;

		var config = buildConfig();
		var input = $('#input').val();

		if (inputType == "remote")
			input = $('#url').val();
		else if (inputType == "json")
			input = $('#json').val();

		// Allow only one parse at a time
		$(this).prop('disabled', true);

		if (!firstRun)
			console.log("--------------------------------------------------");
		else
			firstRun = false;



		if (inputType == "local")
		{//this is the main point of interest to us
			if (!$('#files')[0].files.length)
			{
				alert("Please choose at least one file to parse.");
				return enableButton();
			}
			
			$('#files').parse({
				config: config,
				before: function(file, inputElem)
				{
					start = now();
					console.log("Parsing file...", file);
				},
				error: function(err, file)
				{
					console.log("ERROR:", err, file);
					firstError = firstError || err;
					errorCount++;
				},
                step: function(row) {
                    console.log("Row: ", row.data);
                },
				complete: function()
				{
					end = now();
					printStats("Done with all files");
				}
			});
		}
		else if (inputType == "json")
		{
			if (!input)
			{
				alert("Please enter a valid JSON string to convert to CSV.");
				return enableButton();
			}

			start = now();
			var csv = Papa.unparse(input, config);
			end = now();

			console.log("Unparse complete");
			console.log("Time:", (end-start || "(Unknown; your browser does not support the Performance API)"), "ms");
			
			if (csv.length > maxUnparseLength)
			{
				csv = csv.substr(0, maxUnparseLength);
				console.log("(Results truncated for brevity)");
			}

			console.log(csv);

			setTimeout(enableButton, 100);	// hackity-hack
		}
		else if (inputType == "remote" && !input)
		{
			alert("Please enter the URL of a file to download and parse.");
			return enableButton();
		}
		else
		{
			start = now();
			var results = Papa.parse(input, config);
			console.log("Synchronous results:", results);
			if (config.worker || config.download)
				console.log("Running...");
		}
	});

	$('#insert-tab').click(function()
	{
		$('#delimiter').val('\t');
	});
});




function printStats(msg)
{
	if (msg)
		console.log(msg);
	console.log("       Time:", (end-start || "(Unknown; your browser does not support the Performance API)"), "ms");
	console.log("  Row count:", rowCount);
	if (stepped)
		console.log("    Stepped:", stepped);
	console.log("     Errors:", errorCount);
	if (errorCount)
		console.log("First error:", firstError);
}



function buildConfig()
{
	return {
		delimiter: $('#delimiter').val(),
		header: $('#header').prop('checked'),
		dynamicTyping: $('#dynamicTyping').prop('checked'),
		skipEmptyLines: $('#skipEmptyLines').prop('checked'),
		preview: parseInt($('#preview').val() || 0),
		step: $('#stream').prop('checked') ? stepFn : undefined,
		encoding: $('#encoding').val(),
		worker: $('#worker').prop('checked'),
		comments: $('#comments').val(),
		complete: completeFn,
		error: errorFn,
		download: inputType == "remote"
	};
}
var ruid = "1" ; 
var shall_we_wait = false;  
var ruid2json_result=""; 
var totalNResults = 1;
var currentNResults = 0;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
function wait(){
    while(shall_we_wait ==true){
        sleep(100);
    };
}
/*
setInterval(function(){
  updateProgressBar();
},2000);

var updateProgressBar = function(){     
              var ava = document.getElementById("pbar");
              var div = totalNResults <=1? totalNResults :totalNResults-1;
              document.getElementById("pbar").value = Math.round(currentNResults/div *100) ; 
              //alert("saving the results as csvi in ",filename);
              document.getElementById("pbarPer").innerHTML = ava.value + "%";
}
*/
var getGeocodingJSONFromBase = function(){
    /** call geocoding server API to output all results in JSON, then convert it to csv
    */
    var base_path = "https://www.geohistoricaldata.org/geocoding/geocoding.php/ruid2json"
    var dataString = encodeURI('ruid='+ruid);
    test = $.ajax({
      type: "GET",
      async: false,
      timeout: 10000,
      url: base_path+"?"+dataString,
      dataType: 'JSONP',
      success: function(data){
        console.log("successfully got results associated to ruid") ;
        return data;
      },
      error: function(jqXHR, textStatus, errorThrown){
        if(jqXHR.status==200){
            console.log("here is the returned stuff",jqXHR);
            ruid2json_result= jqXHR.responseText;
            return;
        }else{//ohoh : received a strange return code
          console.log("error in trying to get results associated to ruid : ",ruid);
          alert("error : coulnd't get already geocoded results associated to ruid: "+ruid);
        }
      }
    });
    return;
}





var geocodeOneAdress = function(address, address_date ){
    /** @short Given one line of CSV, prepare an URL and send it to geocoder service
    * @param ""data"" is the output of one line of parse function, provided by stepFn
    */ 
    console.log("address:", address, "address_date", address_date); 
    cleaned_user_n_results = 1;
    cleaned_user_use_precise_localisation = 1 ;
    interactive_editing = ruid ; 
    
    var base_path = "https://www.geohistoricaldata.org/geocoding/geocoding.php"
    var dataString = encodeURI('adresse='+address+'&date='+address_date+'&number_of_results='+cleaned_user_n_results+'&use_precise_localisation='+cleaned_user_use_precise_localisation+'&output_for_interactive_editing='+interactive_editing);
    
    console.log(base_path+"?"+dataString);    

    test = $.ajax({
      type: "GET",
      async: false,
      cache: false,
      timeout: 5000,
      url: base_path+"?"+dataString,//+"&callback=?",
      dataType: 'JSONP',
      success: function(data){
        console.log("successfully send the parameters to geocoding") ; 
        ruid = data["ruid"];
        console.log(ruid);
        shall_we_wait = false;
      },
      error: function(jqXHR, textStatus, errorThrown){ 
        if(jqXHR.status==201 || jqXHR.status==200){
          // we received the expected answer, writting new ruid, loading point from server 
            console.log("here is the returned stuff",jqXHR);
            ruid = JSON.parse(jqXHR.responseText)[0]["ruid"]; 
            console.log("ruid: ",ruid);
        }else{//ohoh : received a strange return code
          console.log("error in geocoding : ",jqXHR,textStatus,errorThrown)
          shall_we_wait = false;
          //alert("error in sending your adresse to geocoder server: "+jqXHR+textStatus+errorThrown);
        }
      }
    }); 
    return; 
}
function stepFn(results, parser)
{   
	stepped++;
	if (results)
	{
		if (results.data)
			rowCount += results.data.length;
            //geocoding the adresse 
            // shall_we_wait = true; 
            // geocodeOneAdress(results.data);
            // wait();
		if (results.errors)
		{
			errorCount += results.errors.length;
			firstError = firstError || results.errors[0];
		}
	}
}

function completeFn(results)
{
	end = now();

	if (results && results.errors)
	{
		if (results.errors)
		{
			errorCount = results.errors.length;
			firstError = results.errors[0];
		}
		if (results.data && results.data.length > 0)
			rowCount = results.data.length;
	}

	//printStats("Parse complete");
	console.log("    Results:", results);
    
    //starting to send the adress to server;
    //check that the required columns names are OK
    if(!results.data[0].address || !results.data[0].address_date){
        alert("error : your csv data must contain a column 'address' and a column 'address_date'") ;
    } 
    skip_line = false ; 
    totalNResults =  results.data.length;
    for (var i = 0; i < results.data.length; i++) { 
        currentNResults=i ;
        skip_line=false ;
        //check quality of input date
        address_date = parseInt(results.data[i].address_date); 
        address = results.data[i].address;
        console.log("add and date : ",address, " ", address_date);
        if(address_date<0 || address_date > 2100){
            alert("you provided an ivalid date :'",address_date,"'"," for address:",address," around line ",i) ;
            skip_line = true;
        }
        if(!address || !address_date){
            alert("you provided an ivalid date or address :'",address_date,"'"," for address:",address," around line ",i) ;
            skip_line = true;
        }
        if(skip_line==false){
            shall_we_wait = true ;
            geocodeOneAdress(address, address_date);
            //wait();
        }
        
        
    }//end loop on all results
    //display ruid for user to access its results
    //open a new tab with ruid for user to edit their results
    //alert("your ruid is :'"+ruid+"' , go to page "+"https://www.geohistoricaldata.org/interactive_geocoding/Leaflet-WFST/examples/geocoding.html"+" and copy your ruid here");
    
    document.getElementById("pbarDiv").hidden=true;
    // putting the ruid in the form for display
    document.getElementById("displayRuid").hidden=false;
    document.getElementById("textRuid").value=ruid;


	// icky hack
	setTimeout(enableButton, 100);
}

function errorFn(err, file)
{
	end = now();
	console.log("ERROR:", err, file);
	enableButton();
}

function enableButton()
{
	$('#submit').prop('disabled', false);
}

function now()
{
	return typeof window.performance !== 'undefined'
			? window.performance.now()
			: 0;
}




window.onload = function(){
var urlParams = new URLSearchParams(window.location.search);
if(urlParams.has('ruid') && String(urlParams.get('ruid')).length==32){
  ruid = urlParams.get('ruid');
  document.getElementById("textRuid").value = urlParams.get('ruid');
  //displayng button
  document.getElementById("displayRuid").hidden = false ; 
  //simulating click on button
}
}
