<?php
require_once("inc.php");


//$rel=get_node(62);
//$rel->setProperty("type","rel")->save();

// Connecting to the default port 7474 on localhost


// Connecting to a different port or host
//$client = new Everyman\Neo4j\Client('localhost', 7474);
function find_num_of_nodes($filename){
	$file= fopen("../".$filename,"r");
	$max = 0;
	$counter = 0;
	while (!feof($file)){
		$line=fgets($file);
		list($node1,$node2,$relation) = explode(",",$line);
		if ($counter==0){
			echo $relation."<br/>";
			$counter++;
		}
		else if ($counter>0) {
			$node1 = (int) $node1;
			$node2 = (int) $node2;
			//if that happens we are reading the same nodes again - so break!
			if ($node1>$node2){
				break;
			}
			if ($node1 > $max) {
			   $max = (int) $node1;
			}
			if ($node2 > $max) {
				$max = (int) $node2;
			}
		}
		

	}
	fclose($file);
	return $max;
}

function add_relations($filename){
	$file= fopen("../".$filename,"r");
	$max = 0;
	$counter = 0;
	$relation ="";

	while (!feof($file)){
		$line=fgets($file);
		list($node1,$node2,$rel) = explode(",",$line);
		if ($counter==0){
			$relation=$rel;
			$counter++;
		}
		else if ($counter>0) {
			$node1 = get_node_by_title($node1);
			$node2 = get_node_by_title($node2);
			insert_relation($node1,$node2,$relation);
		}

	}
	fclose($file);

}



neo4j_reset();
$filename = "input-tuples-sparse.csv";
$max = find_num_of_nodes($filename);

for ($i=0;$i<=$max;$i++){
	insert_node($i);
	echo "bika";
}
add_relations($filename);




//$nodes = new Everyman\Neo4j\Index\NodeIndex($db, 'node');

?>