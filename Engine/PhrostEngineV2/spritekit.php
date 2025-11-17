<?php
declare(strict_types=1);

sprite_start(800, 600, "Moving Boxes");
$id1 = sprite_rect(120, 120, 60, 60);
$id2 = sprite_rect(300, 200, 100, 40);

sprite_set_velocity($id1, 3, 2);
sprite_set_velocity($id2, -2.5, 1.5);

for ($i = 0; $i < 3000; $i++) {
    sprite_pump();
}
sprite_close();