<?php

function get_node_by_id($id) { //NEO4J
	global $db;
	return $db->getNode($id);

}

function get_node_by_title($title) {
	global $db;
	$nodeIndex = new Everyman\Neo4j\Index\NodeIndex($db, 'node');
	$node=$nodeIndex->findOne("title",$title);
	if (!$node) {
        return null;
    }
	return $node;
}



function insert_node($input) {
	global $db;
	if (!empty($input)) {
		$node = $db->makeNode();
		$node->setProperty("title",$input);
		$node->save();
		index_node($node);
	}
	return $neo4jnode;
}

function insert_relation($node1,$node2,$relation_type) {
	global $db;
	$rel_index = new Everyman\Neo4j\Index\RelationshipIndex($db, $relation_type);
	$relation=$node1->relateTo($node2,$relation_type)->save();
	$rel_index->add($relation,'type',$relation_type);
}

function index_node($node) {
	global $db;
	$nodeIndex = new Everyman\Neo4j\Index\NodeIndex($db, 'node');
	$nodeIndex->add($node,'title',$node->getProperty('title'));
}

function neo4j_reset(){
	global $db;
	$queryString="START n = node(*) MATCH n-[r?]-() DELETE n, r";
	$query = new Everyman\Neo4j\Cypher\Query($db, $queryString);
	$result = $query->getResultSet();
}


?>
