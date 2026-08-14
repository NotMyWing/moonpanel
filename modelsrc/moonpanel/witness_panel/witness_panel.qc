$modelname "moonpanel/witness_panel.mdl"
$body "body" "witness_panel_reference.smd"
$surfaceprop "metal"
$contents "solid"
$cdmaterials "models/moonpanel/witness_panel/"

$sequence "idle" "witness_panel_reference.smd" fps 1

$collisionmodel "witness_panel_collision.smd"
{
	$mass 12
	$inertia 1
	$damping 0.2
	$rotdamping 2
}
