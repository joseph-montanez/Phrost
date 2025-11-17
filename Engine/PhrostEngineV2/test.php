<?php
/**
 * A computationally-intensive benchmark that calculates the sum of the
 * distances between every unique pair of vectors in the array.
 * This is an O(n^2) operation.
 */
function php_total_pairwise_distance(array $vectors): float
{
    $totalDistance = 0.0;
    $count = count($vectors);

    for ($i = 0; $i < $count; $i++) {
        for ($j = $i + 1; $j < $count; $j++) {
            $dx = $vectors[$i]->x - $vectors[$j]->x;
            $dy = $vectors[$i]->y - $vectors[$j]->y;
            $dz = $vectors[$i]->z - $vectors[$j]->z;
            $totalDistance += sqrt($dx * $dx + $dy * $dy + $dz * $dz);
        }
    }

    return $totalDistance;
}

// Swift Register Functions
var_dump(confirm_raylib_compiled(), raylib_hello("John"));

// Swift register PHP Class
$p = new \raylib\Vector3(); 
$p->x = $p->x + 1;
$p->z+= 1;
$p->y++;
var_dump($p);

// Swfit register namespaced functions
$numVectors = 50_000; // The number of Vector3 objects to create.
$numIterations = 100;   // How many times to run each function to get a stable average.

// --- 1. Generate Test Data ---
echo "Generating test data...\n";
$vectors = [];
for ($i = 0; $i < $numVectors; $i++) {
    $vectors[] = new \raylib\Vector3(
        rand(0, 100) / 10.0,
        rand(0, 100) / 10.0,
        rand(0, 100) / 10.0
    );
}
echo "Test data generated.\n\n";

$smallVectorSet = array_slice($vectors, 0, 2000);

printf("\n--- Benchmarking Pairwise Distance ---\n");
printf("Running PHP version with %s vectors...\n", number_format(count($smallVectorSet)));
$startPhp = microtime(true);
$phpDistance = php_total_pairwise_distance($smallVectorSet);
$endPhp = microtime(true);
$phpTime = $endPhp - $startPhp;
printf("PHP Time: %.4f seconds\n", $phpTime);

printf("\nRunning Swift version with %s vectors...\n", number_format(count($vectors)));
$startSwift = microtime(true);
$swiftDistance = \raylib\total_pairwise_distance($vectors); // Your new namespaced function
$endSwift = microtime(true);
$swiftTime = $endSwift - $startSwift;
printf("Swift Time: %.4f seconds\n", $swiftTime);

$speedup = ($phpTime / count($smallVectorSet)**2) / ($swiftTime / count($vectors)**2);
printf("\n✅ Swift extension is roughly %.2f times faster on a per-operation basis.\n", $speedup);
