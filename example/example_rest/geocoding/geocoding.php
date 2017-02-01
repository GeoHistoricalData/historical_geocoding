<?php

use \Psr\Http\Message\ServerRequestInterface as Request;
use \Psr\Http\Message\ResponseInterface as Response;

require './vendor/autoload.php';

$config['displayErrorDetails'] = true;
$config['addContentLengthHeader'] = false;


function connect_to_db()
{
    // echo "connecting to database.\n";
    $pg_string = "host=localhost"; 
    $pg_string = $pg_string." port=5433"; 
    $pg_string = $pg_string." dbname=test";
    $pg_string = $pg_string." user=geocoding_user";
    $pg_string = $pg_string." password=geocoding_user";
    $pg_string = $pg_string." connect_timeout=5 options='--application_name=geoding_rest_api'";
    
    //print("pg_string : ".print_r($pg_string,true)) ; 
    $dbconn = pg_connect($pg_string) or die('connection to database failed');
    //echo "connection to database successful.\n";
    return $dbconn;
}

function sanitize_text($dirty_text){
    // remove non printable characters
    $dirty_text = preg_replace('/[[:^print:]]/', "", $dirty_text);
    //iteratively loop and remove sql comments dans chr( command
    
    do {
         $temp_var = $dirty_text ;
         //remove comments
         preg_replace('/\/\*/i',"", $dirty_text);
         preg_replace('/--/i',"", $dirty_text);
         //remove chr(
         preg_replace('/chr\(/i',"", $dirty_text);
    } while($temp_var != $dirty_text);

    //removing SQL key words
    $wordlist = array("CREATE", "DELETE", "DROP", "UPDATE", "INSERT", "SET", "ALTER");
    do{ // we have to loop because words could be mixed has a possible attack
         $temp_var = $dirty_text ;
	    foreach($wordlist as $word){
	          $dirty_text = str_ireplace($word, "", $dirty_text); 
	    }
    } while ($temp_var != $dirty_text);
    
    //removing potential html or php tag that could be displayed in the result and attack the user
    $adresse = strip_tags ($dirty_text) ;
    //escaping the adresse properly so to avoid sql attack
    $dirty_text = pg_escape_string(utf8_encode($dirty_text)) ;
    
    return $dirty_text ; 
}

function sanitize_input(&$adresse,&$date,&$n_results){
    //sanitizing input to prevent error and exploits, adding default values
    //cleaning n_results
    $n_results  = max(min($n_results, 300), 1);
    //cleaning date
    $date = max(min($date,2100),1800);
    //cleaning adresse
    $adresse = sanitize_text($adresse);  
    print_r("sanitized value of n_results: ".$n_results,true) ;
}
    

function retrieve_results_from_db($adresse,$date,$n_results,$precise_localisation,$interactive_return){
    $dbconn = connect_to_db() ;
	
	// case when we do need the results
	if ($interactive_return == false) {
		/*prepare query and send it*/
		$query = " 
		SELECT rank::text, historical_name::text, normalised_name::text
			, CASE WHEN ST_NumGeometries(geom2) =1 THEN ST_AsText(ST_GeometryN(geom2,1)) ELSE ST_AsText(geom2) END AS geom
			, historical_source::text, numerical_origin_process::text
			, historical_geocoding.round(semantic_distance::float,3 )as semantic_distance , historical_geocoding.round(temporal_distance::float,3) AS temporal_distance
			, historical_geocoding.round(number_distance::float,3) number_distance, historical_geocoding.round(scale_distance::float,3) scale_distance, historical_geocoding.round(spatial_distance::float,3) spatial_distance 
			, historical_geocoding.round(aggregated_distance::float,6) aggregated_distance
			, historical_geocoding.round(spatial_precision::float,2) spatial_precision
			, historical_geocoding.round(confidence_in_result::float,3) confidence_in_result
		FROM historical_geocoding.geocode_name_foolproof(
		query_adress:=$1,
		query_date:= sfti_makesfti($2::integer) ,
		use_precise_localisation:= $4::integer::boolean ,
		max_number_of_candidates:=$3::integer
		  ) As f
		,ST_SnapToGrid(geom,0.01) AS geom2 ; " ;
		$result = pg_query_params($dbconn, $query, array($adresse,$date,$n_results,$precise_localisation));
		if (!$result) {
		  echo "geocoding found no suitable result, have you indicated the city? : 12 rue du temple, PARIS\n";
		  exit;
		}
		$all_res_row = pg_fetch_all($result);

		//print(" <br> results : ".print_r($all_res_row,true)." <br>end result<br> \n");
		pg_close($dbconn) ;
		return $all_res_row; 
	} else{
		//case when the geocoding results are written in the result table, and a random unique identifier is returned.
		$query = "  
		WITH inserting AS (
			INSERT INTO geocoding_edit.geocoding_results (rank, historical_name, normalised_name ,  geom , historical_source, numerical_origin_process ,semantic_distance,  temporal_distance, number_distance, scale_distance,spatial_distance , aggregated_distance, spatial_precision, confidence_in_result  ,  ruid)
			SELECT rank::int, historical_name::text, normalised_name::text
				, geom2 
				, historical_source::text, numerical_origin_process::text
				, historical_geocoding.round(semantic_distance::float,3 ) , historical_geocoding.round(temporal_distance::float,3) 
				, historical_geocoding.round(number_distance::float,3) , historical_geocoding.round(scale_distance::float,3)  , historical_geocoding.round(spatial_distance::float,3)  
				, historical_geocoding.round(aggregated_distance::float,6) 
				, historical_geocoding.round(spatial_precision::float,2) 
				, historical_geocoding.round(confidence_in_result::float,3)  
				, ruid 
			FROM historical_geocoding.geocode_name_foolproof(
			query_adress:=$1,
			query_date:= sfti_makesfti($2::integer) ,
			use_precise_localisation:= $4::integer::boolean ,
			max_number_of_candidates:=$3::integer
			  ) As f
			,ST_Transform(ST_Centroid(ST_SnapToGrid(geom,0.01)),4326) AS geom2
			, geocoding_edit.make_ruid() AS ruid
		RETURNING ruid 
		)SELECT ruid FROM inserting LIMIT 1 ; " ;
		$result = pg_query_params($dbconn, $query, array($adresse,$date,$n_results,$precise_localisation));
		if (!$result) {
		  echo "geocoding found no suitable result, have you indicated the city? : 12 rue du temple, PARIS\n";
		  exit;
		}
		$all_res_row = pg_fetch_all($result);

		//print(" <br> results : ".print_r($all_res_row,true)." <br>end result<br> \n");
		pg_close($dbconn) ;
		return $all_res_row;
	}

}

$app = new \Slim\App(["settings" => $config]);

$app->get('/', function ($request, $response, $args) {
    
    $qparams = $request->getQueryParams();
    $adresse = $request->getQueryParam("adresse", $default = "10 rue du temple, Paris");
    $date = intval($request->getQueryParam("date", $default = "1870"));
    $n_results = intval($request->getQueryParam("number_of_results", $default = "1"));
    $precise_localisation =(int)boolval($request->getQueryParam("use_precise_localisation", $default = "TRUE"));
	$interactive_return =(int)(bool)intval($request->getQueryParam("output_for_interactive_editing", $default = "0"));

    sanitize_input($adresse,$date,$n_results);
	
	if 	($interactive_return==false){
		$json_results = retrieve_results_from_db($adresse,$date,$n_results,$precise_localisation,$interactive_return);
		return $response->withStatus(200)->write(json_encode($json_results));
	}else{
		$json_results = retrieve_results_from_db($adresse,$date,$n_results,$precise_localisation,$interactive_return);
		return $response->withStatus(201)->write(json_encode($json_results));
	}
		
    


    
    //return $response->withStatus(200)->write($n_results);
});

$app->run();
?>
