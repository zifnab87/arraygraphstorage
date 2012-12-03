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
		$line = fgets($file);
		$line = trim($line);
		if (empty($line) || $line=="")
			break;
		list($node1,$node2,$relation) = explode(",",$line);
		if ($counter==0){
			//echo $relation."<br/>";
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
	echo $max;
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
		$line = trim($line);
		//echo "~~~".$line."~~~";
		if (empty($line) || $line=="")
			break;
		list($node1,$node2,$rel) = explode(",",$line);
		if ($counter==0){
			$relation=$rel;
			$counter++;
		}
		else if ($counter>0) {
			echo "~~".$node1."~~<br/>";
			echo "~~".$node2."~~<br/>";
			$node1 = get_node_by_title((string)$node1);
			$node2 = get_node_by_title((string)$node2);
			if ($node1==null || $node2==null){
				break;
			}
			if ($node1!=null && $node2!=null){
				echo $bika;
				insert_relation($node1,$node2,$relation);
			}
		}

	}
	fclose($file);

}



neo4j_reset();
$filename = "input-tuples-sparse.csv";
$max = find_num_of_nodes($filename);

for ($i=0;$i<=$max;$i++){
	$node=insert_node((string)$i);
}
add_relations($filename);




//$nodes = new Everyman\Neo4j\Index\NodeIndex($db, 'node');

?>