// === NASA-STYLE HEXAGONAL CHAINMAIL v5l ===
// All rings same direction - no alternation

// Grid parameters
hex_count_x = 20;
hex_count_y = 20;

// === MASTER SIZE - Change this to scale everything ===
hex_radius = 6;          // Outer radius (center to vertex)

// === PROPORTIONS (as ratios of hex_radius) ===
// Adjust these to change relative proportions
tile_thickness_ratio = 0.15;    // Thickness of flat hex top
post_radius_ratio = 0.20;       // Radius of center cylinder
post_height_ratio = 0.60;       // How far post extends below tile
cap_radius_ratio = 0.50;        // Radius of the center cap
cap_height_ratio = 0.20;        // Center cap height
ring_major_ratio = 0.40;        // Major radius of torus (ring size)
ring_minor_ratio = 0.08;        // Minor radius (wire thickness)
ring_overhang_ratio = 0.075;    // How far rings extend past hex edge
ring_twist_ratio = 0.30;        // How much Z variation (helix height)
ring_clearance_ratio = 0.04;    // Print-in-place gap

// Ring tilt (angle - doesn't scale)
ring_tilt = 45;

// === DERIVED DIMENSIONS (auto-calculated from hex_radius) ===
tile_thickness = hex_radius * tile_thickness_ratio;
post_radius = hex_radius * post_radius_ratio;
post_height = hex_radius * post_height_ratio;
cap_radius = hex_radius * cap_radius_ratio;
cap_height = hex_radius * cap_height_ratio;
ring_major_r = hex_radius * ring_major_ratio;
ring_minor_r = hex_radius * ring_minor_ratio;
ring_overhang = hex_radius * ring_overhang_ratio;
ring_twist = hex_radius * ring_twist_ratio;
ring_clearance = hex_radius * ring_clearance_ratio;

hex_apothem = hex_radius * cos(30);
spacing_x = hex_apothem * 2 + ring_clearance;
spacing_y = hex_radius * 1.5 + ring_clearance;
ring_center_dist = post_radius + ring_major_r - ring_minor_r + ring_overhang;

$fn = 32;
ring_segments = 64;

// === MODULES ===

module hexagon_2d(radius) {
    polygon([for (i = [0:5]) [radius * cos(60*i + 30), radius * sin(60*i + 30)]]);
}

module hex_tile() {
    linear_extrude(tile_thickness)
        hexagon_2d(hex_radius);
}

module center_post() {
    translate([0, 0, -post_height])
        cylinder(r = post_radius, h = post_height);
}

module center_cap() {
    translate([0, 0, -post_height-(cap_height/2)])
    cylinder(r = cap_radius, h = cap_height);
}

module twisted_ring() {
    // Helical ring - Z varies around the ring
    path_points = [
        for (a = [0 : 360/ring_segments : 359])
            [
                ring_major_r * cos(a),
                ring_major_r * sin(a),
                ring_twist * sin(a) / 2
            ]
    ];
    
    for (i = [0 : len(path_points) - 1]) {
        scale([1,1,0.5]){
        hull() {
            translate(path_points[i])
                sphere(r = ring_minor_r);
            translate(path_points[(i + 1) % len(path_points)])
                sphere(r = ring_minor_r);
        }
    }
    }
}

module chainmail_hex_tile() {
    union() {
        // Flat hex top
        hex_tile();
        
        // Central post
        center_post();
        
        // 6 twisted rings - all same direction
        for (i = [0:5]) {
            rotate([0, 0, i * 60])
            translate([ring_center_dist, 0, -post_height/2])
            rotate([ring_tilt, 0, 0])
                twisted_ring();
        }
        
        center_cap();
    }
}

// === GRID ASSEMBLY ===

module hex_chainmail_grid() {
    for (row = [0 : hex_count_y - 1]) {
        for (col = [0 : hex_count_x - 1]) {
            x_offset = (row % 2 == 0) ? 0 : hex_apothem + ring_clearance/2;
            
            translate([col * spacing_x + x_offset, row * spacing_y, post_height])
                chainmail_hex_tile();
        }
    }
}

// === RENDER ===

hex_chainmail_grid();