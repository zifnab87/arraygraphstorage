<?php

function get_neo4jnode($id) { //NEO4J
	global $db;
	return $db->getNode($id);
}

function get_node($id) { //NEO4J
	$node=get_neo4jnode($id);
	if ($node->getProperty('type')=="node") {
		return $node;
	}
	return null;
}



function insert_neo4jnode($input,$type) {
	global $db;
	if (!empty($input)) {
		$FullIndex = new Everyman\Neo4j\Index\NodeFulltextIndex($db, $type."full");
		$neo4jnode = $db->makeNode();
		$neo4jnode->setProperty("title",$input);
		$neo4jnode->save();
		//index_node($neo4jnode);
	}
	return $neo4jnode;
}

?>
